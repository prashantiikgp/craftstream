// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoutesSchema _$RoutesSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RoutesSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['initial', 'routes']);
      final val = RoutesSchema(
        initial: $checkedConvert('initial', (v) => v as String),
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
      $checkKeys(
        json,
        allowedKeys: const ['path', 'screen', 'legacy', 'dev_only', 'routes'],
      );
      final val = RouteSchema(
        path: $checkedConvert('path', (v) => v as String),
        screen: $checkedConvert('screen', (v) => v as String?),
        legacy: $checkedConvert('legacy', (v) => v as String?),
        devOnly: $checkedConvert('dev_only', (v) => v as bool? ?? false),
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
    }, fieldKeyMap: const {'devOnly': 'dev_only'});
