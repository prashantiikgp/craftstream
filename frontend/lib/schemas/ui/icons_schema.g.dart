// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'icons_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IconsSchema _$IconsSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('IconsSchema', json, ($checkedConvert) {
  $checkKeys(json, allowedKeys: const ['view_box', 'stroke_width', 'icons']);
  final val = IconsSchema(
    viewBox: $checkedConvert('view_box', (v) => (v as num).toDouble()),
    strokeWidth: $checkedConvert('stroke_width', (v) => (v as num).toDouble()),
    icons: $checkedConvert(
      'icons',
      (v) => (v as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, IconSchema.fromJson(e as Map<String, dynamic>)),
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'viewBox': 'view_box', 'strokeWidth': 'stroke_width'});

IconSchema _$IconSchemaFromJson(Map<String, dynamic> json) => $checkedCreate(
  'IconSchema',
  json,
  ($checkedConvert) {
    $checkKeys(json, allowedKeys: const ['stroke', 'fill', 'circles']);
    final val = IconSchema(
      stroke: $checkedConvert(
        'stroke',
        (v) =>
            (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      ),
      fill: $checkedConvert(
        'fill',
        (v) =>
            (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      ),
      circles: $checkedConvert(
        'circles',
        (v) =>
            (v as List<dynamic>?)
                ?.map(
                  (e) => (e as List<dynamic>)
                      .map((e) => (e as num).toDouble())
                      .toList(),
                )
                .toList() ??
            const [],
      ),
    );
    return val;
  },
);
