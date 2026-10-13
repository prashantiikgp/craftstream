/// Retry and polling rules for uploads, from upload.yml. Pure Dart.
library;

import '../../schemas/media/upload_schema.dart';

class UploadRulesError implements Exception {
  final String message;
  const UploadRulesError(this.message);
  @override
  String toString() => 'upload.yml: $message';
}

class UploadEngine {
  final UploadSchema rules;

  UploadEngine(this.rules) {
    if (rules.retryBackoffSeconds.isEmpty || rules.retryBackoffSeconds.any((s) => s < 0)) {
      throw const UploadRulesError('retry_backoff_seconds must be a non-empty list of seconds >= 0');
    }
    if (rules.maxRetries < 1) throw const UploadRulesError('max_retries must be at least 1');
    if (rules.statusPollSeconds < 1) throw const UploadRulesError('status_poll_seconds must be at least 1');
    if (rules.statusPollTimeoutMinutes < 1) throw const UploadRulesError('status_poll_timeout_minutes must be >= 1');
  }

  int get maxRetries => rules.maxRetries;
  Duration get statusPollInterval => Duration(seconds: rules.statusPollSeconds);
  Duration get statusPollTimeout => Duration(minutes: rules.statusPollTimeoutMinutes);

  /// Wait before retry number [attempt] (1-based). The last listed value repeats.
  Duration backoff(int attempt) {
    final list = rules.retryBackoffSeconds;
    return Duration(seconds: list[(attempt - 1).clamp(0, list.length - 1)]);
  }

  /// Next chunk to send: from [offset], at most [chunkSize] bytes, never past [total].
  ({int start, int length}) nextChunk({required int offset, required int total, required int chunkSize}) =>
      (start: offset, length: (total - offset).clamp(0, chunkSize));

  /// Does a video of [duration] fit the server's limit?
  static bool fitsDuration(Duration duration, int maxDurationSeconds) => duration.inSeconds <= maxDurationSeconds;
}
