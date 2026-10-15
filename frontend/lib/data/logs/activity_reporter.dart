/// Reports the upload steps only the app sees (started, the network dropped, resumed, finished…) to the activity
/// log. Fire and forget: a report never slows or fails an upload. Reports that cannot be sent (the network is
/// down, which is exactly when an upload is interrupted) wait, oldest first, and go out before the next one.
/// Which steps, as which events and with which values: logs/activity_log.yml.
library;

import 'dart:async';

import '../../domain/logs/activity_log_engine.dart';
import '../generated/models.dart';
import '../repositories/log_repository.dart';

/// An upload step (activity_log.yml `steps`, by its snake_case name).
enum UploadStep {
  tooLong,
  started,
  interrupted,
  resumed,
  finished,
  failed,
  cancelled;

  String get key => name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
}

class ActivityReporter {
  final LogRepository _repo;
  final ActivityLogEngine _rules;
  final List<LogEntryCreate> _pending = [];
  Future<void>? _sending;

  ActivityReporter(this._repo, this._rules);

  /// Reports [step] for [productId] with [values] (only those activity_log.yml lists are sent).
  void step(UploadStep step, {String? productId, Map<String, Object?> values = const {}}) {
    final r = _rules.report(step.key, values);
    if (r == null) return;
    _pending.add(
      LogEntryCreate(
        event: r.event,
        productId: productId,
        details: [for (final (key, value) in r.details) LogDetail(key: key, value: value)],
      ),
    );
    final kept = _rules.keepPending(_pending);
    if (kept.length != _pending.length) _pending.removeRange(0, _pending.length - kept.length);
    unawaited(_flush());
  }

  /// Reports still waiting for the network (oldest first).
  List<LogEntryCreate> get pending => List.unmodifiable(_pending);

  /// Sends what is waiting, one at a time, in order; stops at the first failure and keeps the rest.
  Future<void> _flush() => _sending ??= () async {
    try {
      while (_pending.isNotEmpty) {
        await _repo.report(_pending.first);
        _pending.removeAt(0);
      }
    } catch (_) {
      // Offline or the server refused: keep it for the next report.
    } finally {
      _sending = null;
    }
  }();
}
