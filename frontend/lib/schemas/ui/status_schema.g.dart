// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StatusSchema _$StatusSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('StatusSchema', json, ($checkedConvert) {
  $checkKeys(json, allowedKeys: const ['video', 'order']);
  final val = StatusSchema(
    video: $checkedConvert(
      'video',
      (v) => (v as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, StatusLookSchema.fromJson(e as Map<String, dynamic>)),
      ),
    ),
    order: $checkedConvert(
      'order',
      (v) => (v as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, StatusLookSchema.fromJson(e as Map<String, dynamic>)),
      ),
    ),
  );
  return val;
});

StatusLookSchema _$StatusLookSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('StatusLookSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'label',
          'tone',
          'hint',
          'progress',
          'retry',
          'orderable',
        ],
      );
      final val = StatusLookSchema(
        label: $checkedConvert('label', (v) => v as String),
        tone: $checkedConvert('tone', (v) => v as String),
        hint: $checkedConvert('hint', (v) => v as String?),
        progress: $checkedConvert('progress', (v) => v as bool? ?? false),
        retry: $checkedConvert('retry', (v) => v as bool? ?? false),
        orderable: $checkedConvert('orderable', (v) => v as bool? ?? false),
      );
      return val;
    });
