/// Status looks from status.yml. Pure Dart: bricks ask `look('video', 'processing')` instead of comparing strings.
library;

import '../../schemas/ui/status_schema.dart';

class StatusRulesError implements Exception {
  final String message;
  const StatusRulesError(this.message);
  @override
  String toString() => 'status.yml: $message';
}

class StatusEngine {
  final StatusSchema rules;

  StatusEngine(this.rules) {
    if (rules.video.isEmpty || rules.order.isEmpty) throw const StatusRulesError('video and order need statuses');
    if (rules.video.values.where((l) => l.orderable).length != 1) {
      throw const StatusRulesError('exactly one video status must be orderable: true');
    }
  }

  /// Whether a product with this video status can be watched and bought.
  bool orderable(String videoStatus) => look('video', videoStatus).orderable;

  Map<String, StatusLookSchema> _kind(String kind) => switch (kind) {
        'video' => rules.video,
        'order' => rules.order,
        _ => throw StatusRulesError('unknown status kind "$kind" (video or order)'),
      };

  Iterable<String> get kinds => const ['video', 'order'];

  Iterable<String> values(String kind) => _kind(kind).keys;

  StatusLookSchema look(String kind, String value) =>
      _kind(kind)[value] ?? (throw StatusRulesError('$kind status "$value" is not in status.yml'));

  /// Every tone and strings key the file refers to, for the startup cross-check.
  Iterable<String> get tones => [for (final k in kinds) for (final l in _kind(k).values) l.tone];
  Iterable<String> get stringKeys => [
        for (final k in kinds)
          for (final l in _kind(k).values) ...[l.label, ?l.hint],
      ];
}
