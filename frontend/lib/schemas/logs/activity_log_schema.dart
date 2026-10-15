/// Shape of assets/config/logs/activity_log.yml: the upload steps the app reports and how the Activity log
/// screen pages, refreshes and filters.
library;

import 'package:json_annotation/json_annotation.dart';

part 'activity_log_schema.g.dart';

@JsonSerializable()
class ActivityLogSchema {
  final bool report;
  final Map<String, LogStepSchema> steps;
  final int pendingMax;
  final int pageSize;
  final int refreshSeconds;
  final Map<String, String> groups;
  final Map<String, LogLevelSchema> levels;

  const ActivityLogSchema({
    required this.report,
    required this.steps,
    required this.pendingMax,
    required this.pageSize,
    required this.refreshSeconds,
    required this.groups,
    required this.levels,
  });

  factory ActivityLogSchema.fromJson(Map<String, dynamic> json) => _$ActivityLogSchemaFromJson(json);
}

/// One reported step: the server's event name and the values sent with it.
@JsonSerializable()
class LogStepSchema {
  final String event;
  final List<String> details;

  const LogStepSchema({required this.event, required this.details});

  factory LogStepSchema.fromJson(Map<String, dynamic> json) => _$LogStepSchemaFromJson(json);
}

/// How one level looks: its tone (ui/theme.yml) and its label (a strings.yml key).
@JsonSerializable()
class LogLevelSchema {
  final String tone;
  final String label;

  const LogLevelSchema({required this.tone, required this.label});

  factory LogLevelSchema.fromJson(Map<String, dynamic> json) => _$LogLevelSchemaFromJson(json);
}
