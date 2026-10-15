// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSchema _$AppSchemaFromJson(Map<String, dynamic> json) => $checkedCreate(
  'AppSchema',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const ['name', 'initial_route', 'theme_mode'],
    );
    final val = AppSchema(
      name: $checkedConvert('name', (v) => v as String),
      initialRoute: $checkedConvert('initial_route', (v) => v as String),
      themeMode: $checkedConvert('theme_mode', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'initialRoute': 'initial_route',
    'themeMode': 'theme_mode',
  },
);
