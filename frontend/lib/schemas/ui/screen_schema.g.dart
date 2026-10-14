// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScreenSchema _$ScreenSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ScreenSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'about',
          'data',
          'width',
          'gap',
          'fill',
          'backdrop',
          'top',
          'body',
          'bottom',
          'empty',
          'error',
        ],
      );
      final val = ScreenSchema(
        about: $checkedConvert('about', (v) => v as String),
        data: $checkedConvert('data', (v) => v as String?),
        width: $checkedConvert(
          'width',
          (v) =>
              $enumDecodeNullable(_$ScreenWidthEnumMap, v) ?? ScreenWidth.wide,
        ),
        gap: $checkedConvert('gap', (v) => v as String? ?? 'lg'),
        fill: $checkedConvert('fill', (v) => v as bool? ?? false),
        backdrop: $checkedConvert('backdrop', (v) => v as String?),
        top: $checkedConvert('top', (v) => v as List<dynamic>? ?? const []),
        body: $checkedConvert('body', (v) => v as List<dynamic>),
        bottom: $checkedConvert(
          'bottom',
          (v) => v as List<dynamic>? ?? const [],
        ),
        empty: $checkedConvert('empty', (v) => v as List<dynamic>? ?? const []),
        error: $checkedConvert('error', (v) => v as List<dynamic>? ?? const []),
      );
      return val;
    });

const _$ScreenWidthEnumMap = {
  ScreenWidth.narrow: 'narrow',
  ScreenWidth.wide: 'wide',
};
