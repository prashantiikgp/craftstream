// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoutesSchema _$RoutesSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RoutesSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['routes']);
      final val = RoutesSchema(
        routes: $checkedConvert(
          'routes',
          (v) => (v as List<dynamic>)
              .map((e) => RouteSchema.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

RouteSchema _$RouteSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RouteSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['path', 'screen', 'routes']);
      final val = RouteSchema(
        path: $checkedConvert('path', (v) => v as String),
        screen: $checkedConvert('screen', (v) => v as String),
        routes: $checkedConvert(
          'routes',
          (v) =>
              (v as List<dynamic>?)
                  ?.map((e) => RouteSchema.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              const [],
        ),
      );
      return val;
    });
