/// Retry and polling rules for uploads, from upload.yml. Pure Dart.
library;

import '../../schemas/media/upload_schema.dart';

class UploadRulesError implements Exception {
  final String message;
  const UploadRulesError(this.message);
  @override
  String toString() => 'upload.yml: $message';
}

/// What an answer from the upload session means (upload.yml `http_status`).
enum UploadAnswer {
  /// The whole file has arrived.
  done,

  /// More to send; the Range header says how much arrived.
  more,

  /// A hiccup: back off, ask how much arrived, continue.
  retry,

  /// Refused for good.
  reject,
}

final _statusClass = RegExp(r'^([1-5])xx$');

class UploadEngine {
  final UploadSchema rules;
  late final Map<UploadAnswer, List<Object>> _statuses = {
    UploadAnswer.done: rules.httpStatus.done,
    UploadAnswer.more: rules.httpStatus.more,
    UploadAnswer.retry: rules.httpStatus.retry,
  };

  UploadEngine(this.rules) {
    if (rules.retryBackoffSeconds.isEmpty || rules.retryBackoffSeconds.any((s) => s < 0)) {
      throw const UploadRulesError('retry_backoff_seconds must be a non-empty list of seconds >= 0');
    }
    if (rules.maxRetries < 1) throw const UploadRulesError('max_retries must be at least 1');
    if (rules.statusPollSeconds < 1) throw const UploadRulesError('status_poll_seconds must be at least 1');
    if (rules.statusPollTimeoutMinutes < 1) throw const UploadRulesError('status_poll_timeout_minutes must be >= 1');
    for (final MapEntry(key: answer, value: entries) in _statuses.entries) {
      for (final s in entries) {
        if (!(s is int && s >= 100 && s <= 599) && !(s is String && _statusClass.hasMatch(s))) {
          throw UploadRulesError('http_status.${_yamlName(answer)}: "$s" is not a status code or class like 5xx');
        }
      }
    }
    for (var code = 100; code <= 599; code++) {
      final claimed = [
        for (final MapEntry(key: answer, value: entries) in _statuses.entries)
          if (entries.any((s) => _matches(s, code))) _yamlName(answer),
      ];
      if (claimed.length > 1) throw UploadRulesError('http_status: $code is in both ${claimed.join(' and ')}');
    }
    final p = rules.picker;
    if (p.accept.trim().isEmpty) throw const UploadRulesError('picker.accept must not be empty');
    if (p.metadataTimeoutSeconds < 1) throw const UploadRulesError('picker.metadata_timeout_seconds must be >= 1');
    for (final type in [...p.mimeTypes.values, p.defaultMimeType]) {
      if (!type.contains('/')) throw UploadRulesError('picker: "$type" is not a MIME type');
    }
    if (p.mimeTypes.keys.any((e) => e != e.toLowerCase() || e.startsWith('.'))) {
      throw const UploadRulesError('picker.mime_types: extensions are lower case, without the dot');
    }
    if (rules.tags.separator.isEmpty) throw const UploadRulesError('tags.separator must not be empty');
    if (rules.price.currency.trim().isEmpty) throw const UploadRulesError('price.currency must not be empty');
  }

  static String _yamlName(UploadAnswer a) => a == UploadAnswer.more ? 'continue' : a.name;

  static bool _matches(Object rule, int code) =>
      rule is int ? rule == code : '${code ~/ 100}' == _statusClass.firstMatch('$rule')?.group(1);

  /// What the upload session's HTTP [status] means. Anything upload.yml does not list is a rejection.
  UploadAnswer answerFor(int status) {
    for (final MapEntry(key: answer, value: entries) in _statuses.entries) {
      if (entries.any((s) => _matches(s, status))) return answer;
    }
    return UploadAnswer.reject;
  }

  /// The browser file dialog's `accept`.
  String get pickerAccept => rules.picker.accept;

  /// How long the device may take to read a picked video's length.
  Duration get metadataTimeout => Duration(seconds: rules.picker.metadataTimeoutSeconds);

  /// The type of a file with extension [ext] (any case, no dot), for devices that do not report one.
  String mimeTypeFor(String? ext) => rules.picker.mimeTypes[ext?.toLowerCase()] ?? rules.picker.defaultMimeType;

  /// The listing's tags: the [chosen] chips first, then the [typed] ones (split on the separator, trimmed,
  /// lower case), without repeats, in order.
  List<String> mergeTags(Iterable<String> chosen, String typed) {
    String tidy(String t) => rules.tags.lowerCase ? t.trim().toLowerCase() : t.trim();
    final extra = typed.split(rules.tags.separator).map(tidy).where((t) => t.isNotEmpty);
    return {...chosen, ...extra}.toList();
  }

  /// The typed price as a number, or null when it is not one or is below [min] (the model's minimum).
  double? parsePrice(String raw, {required num min}) {
    var text = raw;
    for (final c in rules.price.ignore) {
      text = text.replaceAll(c, '');
    }
    final v = double.tryParse(text.trim());
    return v == null || !v.isFinite || v < min ? null : v;
  }

  /// The currency every listing is priced in.
  String get currency => rules.price.currency;

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
