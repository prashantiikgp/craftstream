/// New product: the form, the video check against the server's upload policy, and the resumable upload
/// loop (send a chunk, the server confirms an offset; after a drop, back off, ask for the confirmed offset
/// and continue). Then poll until the video is ready. Retry and polling rules come from upload.yml.
/// Each step only the app sees (started, dropped, resumed, finished…) goes to the activity log.
///
/// Not auto-disposed: the upload keeps going if the artisan switches to another screen.
/// Form limits come from models/product.yml via the generated ProductLimits.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../data/generated/api_client.dart';
import '../../data/generated/limits.dart';
import '../../data/generated/models.dart';
import '../../data/logs/activity_reporter.dart';
import '../../data/mock/mock_products.dart';
import '../../data/providers.dart';
import '../../data/repositories/upload_repository.dart';
import '../../data/upload/picked_video.dart';
import '../../domain/media/upload_engine.dart';
import '../studio/studio_controller.dart';

/// Short names for the generated limits, used by the form and its error messages.
const titleMin = ProductLimits.titleMinLength,
    titleMax = ProductLimits.titleMaxLength,
    descriptionMax = ProductLimits.descriptionMaxLength,
    artisanMax = ProductLimits.artisanNameMaxLength,
    tagsMax = ProductLimits.tagsMaxItems;

enum UploadPhase { editing, creating, uploading, paused, reconnecting, processing, live, failed }

enum UploadField { title, description, price, tags, artisan, video }

enum FieldProblem { required, tooShort, tooLong, invalid, tooMany }

enum VideoCheck { ok, unknownLength, tooLong, badType }

final uploadPolicyProvider = FutureProvider<UploadPolicy>((ref) => ref.watch(uploadRepositoryProvider).policy());

VideoCheck checkVideo(PickedVideo video, UploadPolicy policy) {
  if (!policy.allowedMimeTypes.contains(video.mimeType)) return VideoCheck.badType;
  final d = video.duration;
  if (d == null) return VideoCheck.unknownLength;
  return UploadEngine.fitsDuration(d, policy.maxDurationSeconds) ? VideoCheck.ok : VideoCheck.tooLong;
}

class UploadState {
  /// upload.yml: how tags and the price are read.
  final UploadEngine rules;
  final String title, description, price, otherTags, artisanName;
  final Set<String> tags;
  final PickedVideo? video;
  final bool showErrors;
  final UploadPhase phase;
  final UploadTicket? ticket;
  final int sent;
  final int retries;
  final String? error;
  final bool pollGaveUp;

  const UploadState({
    required this.rules,
    this.title = '',
    this.description = '',
    this.price = '',
    this.otherTags = '',
    this.artisanName = '',
    this.tags = const {},
    this.video,
    this.showErrors = false,
    this.phase = UploadPhase.editing,
    this.ticket,
    this.sent = 0,
    this.retries = 0,
    this.error,
    this.pollGaveUp = false,
  });

  int get total => video?.sizeBytes ?? 0;
  double get fraction => total == 0 ? 0 : sent / total;
  bool get busy => phase != UploadPhase.editing;

  double? get priceValue => rules.parsePrice(price, min: ProductLimits.priceMin);

  /// Selected chips plus the typed extras (upload.yml `tags`).
  List<String> get allTags => rules.mergeTags(tags, otherTags);

  Map<UploadField, FieldProblem> get problems {
    final p = <UploadField, FieldProblem>{};
    final t = title.trim().length;
    if (t == 0) {
      p[UploadField.title] = FieldProblem.required;
    } else if (t < titleMin) {
      p[UploadField.title] = FieldProblem.tooShort;
    } else if (t > titleMax) {
      p[UploadField.title] = FieldProblem.tooLong;
    }
    if (description.trim().isEmpty) p[UploadField.description] = FieldProblem.required;
    if (description.length > descriptionMax) p[UploadField.description] = FieldProblem.tooLong;
    if (price.trim().isEmpty) {
      p[UploadField.price] = FieldProblem.required;
    } else if (priceValue == null) {
      p[UploadField.price] = FieldProblem.invalid;
    }
    if (allTags.length > tagsMax) p[UploadField.tags] = FieldProblem.tooMany;
    final a = artisanName.trim().length;
    if (a == 0) p[UploadField.artisan] = FieldProblem.required;
    if (a > artisanMax) p[UploadField.artisan] = FieldProblem.tooLong;
    if (video == null) p[UploadField.video] = FieldProblem.required;
    return p;
  }

  UploadState copyWith({
    String? title,
    String? description,
    String? price,
    String? otherTags,
    String? artisanName,
    Set<String>? tags,
    PickedVideo? video,
    bool? showErrors,
    UploadPhase? phase,
    UploadTicket? ticket,
    int? sent,
    int? retries,
    String? Function()? error,
    bool? pollGaveUp,
  }) => UploadState(
    rules: rules,
    title: title ?? this.title,
    description: description ?? this.description,
    price: price ?? this.price,
    otherTags: otherTags ?? this.otherTags,
    artisanName: artisanName ?? this.artisanName,
    tags: tags ?? this.tags,
    video: video ?? this.video,
    showErrors: showErrors ?? this.showErrors,
    phase: phase ?? this.phase,
    ticket: ticket ?? this.ticket,
    sent: sent ?? this.sent,
    retries: retries ?? this.retries,
    error: error == null ? this.error : error(),
    pollGaveUp: pollGaveUp ?? this.pollGaveUp,
  );
}

class UploadController extends Notifier<UploadState> {
  bool _running = false;
  bool _dropNext = false;
  DateTime? _startedAt;

  @override
  UploadState build() =>
      UploadState(rules: _rules, artisanName: ref.read(appConfigProvider).env.mockData ? mockArtisanName : '');

  UploadRepository get _repo => ref.read(uploadRepositoryProvider);

  /// Reports [step] for the current listing (if any) to the activity log; never waits, never fails.
  void _report(UploadStep step, [Map<String, Object?> values = const {}]) => ref
      .read(activityReporterProvider)
      .step(step, productId: state.ticket?.product.id, values: {'size': state.total, 'sent': state.sent, ...values});
  UploadEngine get _rules => ref.read(appConfigProvider).upload;

  void setTitle(String v) => state = state.copyWith(title: v);
  void setDescription(String v) => state = state.copyWith(description: v);
  void setPrice(String v) => state = state.copyWith(price: v);
  void setOtherTags(String v) => state = state.copyWith(otherTags: v);
  void setArtisanName(String v) => state = state.copyWith(artisanName: v);

  void toggleTag(String tag) {
    final next = {...state.tags};
    if (!next.remove(tag)) next.add(tag);
    state = state.copyWith(tags: next);
  }

  Future<void> pickVideo() async {
    final video = await ref.read(videoPickerProvider).pick();
    if (video != null && ref.mounted) state = state.copyWith(video: video);
  }

  /// Validates, creates the listing, then uploads. Returns false if the form needs attention.
  Future<bool> publish() async {
    final policy = await ref.read(uploadPolicyProvider.future);
    final video = state.video;
    final videoOk =
        video != null && const {VideoCheck.ok, VideoCheck.unknownLength}.contains(checkVideo(video, policy));
    if (state.problems.isNotEmpty || !videoOk) {
      if (video != null && checkVideo(video, policy) == VideoCheck.tooLong) {
        _report(UploadStep.tooLong, {'seconds': video.duration?.inSeconds, 'max': policy.maxDurationSeconds});
      }
      state = state.copyWith(showErrors: true);
      return false;
    }
    state = state.copyWith(phase: UploadPhase.creating, error: () => null);
    try {
      final ticket = await _repo.createListing(
        ProductCreate(
          title: state.title.trim(),
          description: state.description.trim(),
          price: state.priceValue!,
          currency: _rules.currency,
          tags: state.allTags,
          artisanName: state.artisanName.trim(),
        ),
      );
      if (!ref.mounted) return true;
      state = state.copyWith(ticket: ticket, phase: UploadPhase.uploading, sent: 0, retries: 0);
      _startedAt = DateTime.now();
      _report(UploadStep.started, {'chunks': (state.total / ticket.chunkSizeBytes).ceil()});
      ref.invalidate(myProductsProvider);
      _run();
      return true;
    } catch (e) {
      _fail(e);
      return true;
    }
  }

  void pause() {
    if (state.phase == UploadPhase.uploading || state.phase == UploadPhase.reconnecting) {
      state = state.copyWith(phase: UploadPhase.paused);
    }
  }

  void resume() {
    if (state.phase == UploadPhase.paused || (state.phase == UploadPhase.failed && state.ticket != null)) {
      state = state.copyWith(phase: UploadPhase.uploading, retries: 0, error: () => null);
      _run();
    }
  }

  /// DEV_TOOLS demo of R1: the next chunk fails as if the network dropped.
  void simulateDrop() => _dropNext = true;

  /// Back to an empty form (the artisan name is kept).
  void reset() {
    if (state.ticket != null && state.sent < state.total && state.phase != UploadPhase.failed) {
      _report(UploadStep.cancelled);
    }
    state = UploadState(rules: _rules, artisanName: state.artisanName);
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      final ticket = state.ticket!, video = state.video!;
      while (ref.mounted && state.sent < state.total) {
        if (state.phase == UploadPhase.paused || state.phase == UploadPhase.failed) return;
        try {
          if (_dropNext) {
            _dropNext = false;
            throw const UploadInterrupted();
          }
          final chunk = _rules.nextChunk(offset: state.sent, total: state.total, chunkSize: ticket.chunkSizeBytes);
          final confirmed = await _repo.sendChunk(ticket, video, chunk.start, chunk.length);
          if (!ref.mounted) return;
          state = state.copyWith(
            sent: confirmed,
            retries: 0,
            phase: state.phase == UploadPhase.paused ? UploadPhase.paused : UploadPhase.uploading,
          );
        } on UploadInterrupted {
          final attempt = state.retries + 1;
          if (attempt == 1) _report(UploadStep.interrupted, {'reason': UploadInterrupted});
          if (attempt > _rules.maxRetries) {
            state = state.copyWith(phase: UploadPhase.paused);
            return;
          }
          state = state.copyWith(phase: UploadPhase.reconnecting, retries: attempt);
          await Future<void>.delayed(_rules.backoff(attempt));
          if (!ref.mounted || state.phase == UploadPhase.paused) return;
          final confirmed = await _repo.confirmedOffset(ticket, video);
          if (!ref.mounted) return;
          state = state.copyWith(sent: confirmed, phase: UploadPhase.uploading);
          _report(UploadStep.resumed, {'from': confirmed});
        }
      }
      if (!ref.mounted) return;
      final started = _startedAt;
      _report(UploadStep.finished, {if (started != null) 'seconds': DateTime.now().difference(started).inSeconds});
      state = state.copyWith(phase: UploadPhase.processing);
      ref.invalidate(myProductsProvider);
      await _poll(ticket.product.id);
    } catch (e) {
      _fail(e);
    } finally {
      _running = false;
    }
  }

  Future<void> _poll(String productId) async {
    final deadline = DateTime.now().add(_rules.statusPollTimeout);
    while (ref.mounted && state.phase == UploadPhase.processing) {
      if (DateTime.now().isAfter(deadline)) {
        state = state.copyWith(pollGaveUp: true);
        return;
      }
      await Future<void>.delayed(_rules.statusPollInterval);
      if (!ref.mounted) return;
      final p = await _repo.status(productId);
      if (!ref.mounted) return;
      // status.yml says which status is live (orderable) and which one asks for the video again (retry).
      final status = ref.read(appConfigProvider).status;
      if (status.orderable(p.videoStatus)) {
        state = state.copyWith(phase: UploadPhase.live);
        ref.invalidate(myProductsProvider);
      } else if (status.look('video', p.videoStatus).retry) {
        state = state.copyWith(phase: UploadPhase.failed, error: () => null);
        ref.invalidate(myProductsProvider);
      }
    }
  }

  void _fail(Object e) {
    if (!ref.mounted) return;
    final message = e is ApiException ? e.error?.message : null;
    // The server's message or the error's type, never its text: that can hold the upload URL (a credential).
    _report(UploadStep.failed, {'reason': message ?? e.runtimeType});
    state = state.copyWith(phase: UploadPhase.failed, error: () => message);
  }
}

final uploadControllerProvider = NotifierProvider<UploadController, UploadState>(UploadController.new);
