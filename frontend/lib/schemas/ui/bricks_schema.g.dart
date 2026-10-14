// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bricks_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BricksSchema _$BricksSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BricksSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['bricks']);
      final val = BricksSchema(
        bricks: $checkedConvert(
          'bricks',
          (v) => (v as Map<String, dynamic>).map(
            (k, e) =>
                MapEntry(k, BrickSchema.fromJson(e as Map<String, dynamic>)),
          ),
        ),
      );
      return val;
    });

BrickSchema _$BrickSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BrickSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['about', 'props', 'style']);
      final val = BrickSchema(
        about: $checkedConvert('about', (v) => v as String),
        props: $checkedConvert(
          'props',
          (v) => (v as Map<String, dynamic>).map(
            (k, e) =>
                MapEntry(k, PropSchema.fromJson(e as Map<String, dynamic>)),
          ),
        ),
        style: $checkedConvert(
          'style',
          (v) => v as Map<String, dynamic>? ?? const {},
        ),
      );
      return val;
    });

PropSchema _$PropSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PropSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['type', 'required', 'options', 'default'],
      );
      final val = PropSchema(
        type: $checkedConvert('type', (v) => _propType(v)),
        required: $checkedConvert('required', (v) => v as bool? ?? false),
        options: $checkedConvert(
          'options',
          (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
        ),
        defaultValue: $checkedConvert('default', (v) => v),
      );
      return val;
    }, fieldKeyMap: const {'defaultValue': 'default'});
