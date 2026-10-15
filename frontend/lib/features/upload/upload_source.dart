/// Data for ui/screens/upload.yml: the New product form (values, errors as strings keys, the picked video and its
/// check against the server's limit) and, once published, the upload (bytes, phase, step) with the calls that
/// drive it. The upload loop itself stays in upload_controller.dart.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../shared/format/bytes.dart';
import '../../shared/format/money.dart';
import '../../shared/screens/screen_scope.dart';
import 'upload_controller.dart';

const uploadCalls = {
  'set_title',
  'set_description',
  'set_price',
  'set_other_tags',
  'set_artisan',
  'toggle_tag',
  'pick_video',
  'publish',
  'pause',
  'resume',
  'simulate_drop',
  'reset',
};

Map<String, Object?>? _error(UploadState s, UploadField field) {
  if (!s.showErrors) return null;
  return switch ((field, s.problems[field])) {
    (_, null) => null,
    (UploadField.title, FieldProblem.tooShort) => {
      'key': 'upload.title_too_short',
      'args': {'min': titleMin},
    },
    (UploadField.title, FieldProblem.tooLong) => {
      'key': 'upload.title_too_long',
      'args': {'max': titleMax},
    },
    (UploadField.description, FieldProblem.tooLong) => {
      'key': 'upload.description_too_long',
      'args': {'max': descriptionMax},
    },
    (UploadField.price, FieldProblem.invalid) => {'key': 'upload.price_invalid'},
    (UploadField.tags, FieldProblem.tooMany) => {
      'key': 'upload.tags_too_many',
      'args': {'max': tagsMax},
    },
    (UploadField.artisan, FieldProblem.tooLong) => {
      'key': 'upload.artisan_too_long',
      'args': {'max': artisanMax},
    },
    _ => {'key': 'upload.required'},
  };
}

/// Index of the current step: listing created, uploading, processing, live (past the end once live).
int _step(UploadPhase p) => switch (p) {
  UploadPhase.editing || UploadPhase.creating => 0,
  UploadPhase.uploading || UploadPhase.paused || UploadPhase.reconnecting => 1,
  UploadPhase.processing || UploadPhase.failed => 2,
  UploadPhase.live => 4,
};

ScreenData uploadSource(WidgetRef ref, Map<String, String> params) {
  final config = ref.watch(appConfigProvider);
  final s = ref.watch(uploadControllerProvider);
  final c = ref.read(uploadControllerProvider.notifier);
  final policy = ref.watch(uploadPolicyProvider).value;
  final max = policy == null ? null : formatDuration(Duration(seconds: policy.maxDurationSeconds));
  final video = s.video;
  final check = video == null || policy == null ? null : checkVideo(video, policy);
  final arrived = s.total > 0 && s.sent >= s.total;
  final canResume = s.phase == UploadPhase.failed && s.ticket != null && s.sent < s.total;
  final phase = s.phase;
  return ScreenData.ready(
    {
      'upload': {
        'editing': !s.busy,
        'busy': s.busy,
        'title': s.title,
        'description': s.description,
        'price': s.price,
        'other_tags': s.otherTags,
        'artisan': s.artisanName,
        'errors': {for (final f in UploadField.values) f.name: _error(s, f)},
        'tags': [
          for (final t in config.filters.rules.featuredTags) {'value': t, 'selected': s.tags.contains(t)},
        ],
        'tags_max': tagsMax,
        'video': {
          'picked': video != null,
          'missing': s.showErrors && video == null,
          'name': video?.name,
          'details': video == null
              ? null
              : [formatBytes(video.sizeBytes), if (video.duration != null) formatDuration(video.duration!)].join(' · '),
          'max': max,
        },
        'check': {
          'ok': check == VideoCheck.ok,
          'too_long': check == VideoCheck.tooLong,
          'unknown': check == VideoCheck.unknownLength,
          'bad_type': check == VideoCheck.badType,
          'duration': video?.duration == null ? null : formatDuration(video!.duration!),
          'max': max,
        },
        'show_fix': s.showErrors && s.problems.isNotEmpty,
        // After Publish
        'summary_price': formatMoney(s.priceValue ?? 0, s.rules.currency),
        'file': video?.name,
        'creating': phase == UploadPhase.creating,
        'sending': s.busy && !arrived && phase != UploadPhase.creating,
        'arrived': s.busy && arrived,
        'fraction': s.fraction,
        'sent': formatBytes(s.sent),
        'total': formatBytes(s.total),
        'percent': (s.fraction * 100).floor(),
        'chunk': s.ticket == null ? null : formatBytes(s.ticket!.chunkSizeBytes),
        'transferring': const {UploadPhase.uploading, UploadPhase.reconnecting, UploadPhase.paused}.contains(phase),
        'uploading': phase == UploadPhase.uploading,
        'paused': phase == UploadPhase.paused,
        'reconnecting': phase == UploadPhase.reconnecting,
        'retries': s.retries,
        'processing': phase == UploadPhase.processing,
        'poll_slow': s.pollGaveUp,
        'live': phase == UploadPhase.live,
        'failed': phase == UploadPhase.failed,
        'can_resume': canResume,
        'cannot_resume': phase == UploadPhase.failed && !canResume,
        'failure': s.error,
        'keep_open': const {UploadPhase.creating, UploadPhase.uploading}.contains(phase),
        'drop_demo': config.env.devTools && phase == UploadPhase.uploading,
        'product_id': s.ticket?.product.id,
        'step': _step(phase),
      },
    },
    {
      'set_title': (v) => c.setTitle('${v ?? ''}'),
      'set_description': (v) => c.setDescription('${v ?? ''}'),
      'set_price': (v) => c.setPrice('${v ?? ''}'),
      'set_other_tags': (v) => c.setOtherTags('${v ?? ''}'),
      'set_artisan': (v) => c.setArtisanName('${v ?? ''}'),
      'toggle_tag': (v) => c.toggleTag('$v'),
      'pick_video': (_) => c.pickVideo(),
      'publish': (_) => c.publish(),
      'pause': (_) => c.pause(),
      'resume': (_) => c.resume(),
      'simulate_drop': (_) => c.simulateDrop(),
      'reset': (_) => c.reset(),
    },
  );
}
