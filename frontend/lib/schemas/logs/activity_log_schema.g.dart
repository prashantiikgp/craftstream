// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_log_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityLogSchema _$ActivityLogSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ActivityLogSchema',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'report',
        'steps',
        'pending_max',
        'page_size',
        'refresh_seconds',
        'groups',
        'levels',
      ],
    );
    final val = ActivityLogSchema(
      report: $checkedConvert('report', (v) => v as bool),
      steps: $checkedConvert(
        'steps',
        (v) => (v as Map<String, dynamic>).map(
          (k, e) =>
              MapEntry(k, LogStepSchema.fromJson(e as Map<String, dynamic>)),
        ),
      ),
      pendingMax: $checkedConvert('pending_max', (v) => (v as num).toInt()),
      pageSize: $checkedConvert('page_size', (v) => (v as num).toInt()),
      refreshSeconds: $checkedConvert(
        'refresh_seconds',
        (v) => (v as num).toInt(),
      ),
      groups: $checkedConvert(
        'groups',
        (v) => Map<String, String>.from(v as Map),
      ),
      levels: $checkedConvert(
        'levels',
        (v) => (v as Map<String, dynamic>).map(
          (k, e) =>
              MapEntry(k, LogLevelSchema.fromJson(e as Map<String, dynamic>)),
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'pendingMax': 'pending_max',
    'pageSize': 'page_size',
    'refreshSeconds': 'refresh_seconds',
  },
);

LogStepSchema _$LogStepSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LogStepSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['event', 'details']);
      final val = LogStepSchema(
        event: $checkedConvert('event', (v) => v as String),
        details: $checkedConvert(
          'details',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
      );
      return val;
    });

LogLevelSchema _$LogLevelSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LogLevelSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['tone', 'label']);
      final val = LogLevelSchema(
        tone: $checkedConvert('tone', (v) => v as String),
        label: $checkedConvert('label', (v) => v as String),
      );
      return val;
    });
