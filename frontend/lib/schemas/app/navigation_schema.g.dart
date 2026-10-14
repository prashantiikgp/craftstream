// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NavigationSchema _$NavigationSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NavigationSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['roles']);
      final val = NavigationSchema(
        roles: $checkedConvert(
          'roles',
          (v) => (v as Map<String, dynamic>).map(
            (k, e) =>
                MapEntry(k, RoleSchema.fromJson(e as Map<String, dynamic>)),
          ),
        ),
      );
      return val;
    });

RoleSchema _$RoleSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RoleSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['number', 'label', 'accent', 'home', 'paths'],
      );
      final val = RoleSchema(
        number: $checkedConvert('number', (v) => v as String),
        label: $checkedConvert('label', (v) => v as String),
        accent: $checkedConvert('accent', (v) => v as String),
        home: $checkedConvert('home', (v) => v as String),
        paths: $checkedConvert(
          'paths',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
      );
      return val;
    });
