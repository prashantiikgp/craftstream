/// Which upload steps the app reports, as which event and with which values; how the Activity log screen pages,
/// refreshes and filters (activity_log.yml). Pure Dart.
library;

import '../../schemas/logs/activity_log_schema.dart';

class ActivityLogRulesError implements Exception {
  final String message;
  const ActivityLogRulesError(this.message);
  @override
  String toString() => 'activity_log.yml: $message';
}

/// A step ready to send: the server's event name and its values as text, in the order activity_log.yml lists.
typedef LogReport = ({String event, List<(String, String)> details});

class ActivityLogEngine {
  final ActivityLogSchema rules;

  ActivityLogEngine(this.rules) {
    if (rules.pendingMax < 0) throw const ActivityLogRulesError('pending_max must be 0 or more');
    if (rules.pageSize < 1) throw const ActivityLogRulesError('page_size must be at least 1');
    if (rules.refreshSeconds < 0) throw const ActivityLogRulesError('refresh_seconds must be 0 or more');
    for (final MapEntry(:key, :value) in rules.steps.entries) {
      if (value.event.trim().isEmpty) throw ActivityLogRulesError('steps.$key has no event');
    }
  }

  bool get reports => rules.report;
  int get pendingMax => rules.pendingMax;
  int get pageSize => rules.pageSize;
  Iterable<String> get stepNames => rules.steps.keys;
  Iterable<String> get groups => rules.groups.keys;
  Iterable<String> get levels => rules.levels.keys;

  /// The strings.yml key that names a group or a level (falls back to the value itself, as data).
  String? groupLabel(String group) => rules.groups[group];
  String? levelLabel(String level) => rules.levels[level]?.label;

  /// Every strings.yml key this file names (the strings test counts them as used).
  Iterable<String> get stringKeys => [...rules.groups.values, for (final l in rules.levels.values) l.label];

  /// How often the open screen re-reads the newest page; null means only when asked.
  Duration? get refresh => rules.refreshSeconds == 0 ? null : Duration(seconds: rules.refreshSeconds);

  /// The tone (ui/theme.yml) a level is shown in.
  String toneOf(String level) => (rules.levels[level] ?? rules.levels.values.first).tone;

  /// [step] as the server's event with the values activity_log.yml lists for it (missing values are left out).
  /// Null when the app does not report this step or reporting is off.
  LogReport? report(String step, Map<String, Object?> values) {
    final s = rules.steps[step];
    if (!rules.report || s == null) return null;
    return (
      event: s.event,
      details: [
        for (final key in s.details)
          if (values[key] != null) (key, '${values[key]}'),
      ],
    );
  }

  /// Keeps the newest [pendingMax] of [pending] (oldest first).
  List<T> keepPending<T>(List<T> pending) =>
      pending.length <= rules.pendingMax ? pending : pending.sublist(pending.length - rules.pendingMax);
}
