// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strings_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StringsSchema _$StringsSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('StringsSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['locale', 'strings']);
      final val = StringsSchema(
        locale: $checkedConvert('locale', (v) => v as String),
        strings: $checkedConvert(
          'strings',
          (v) => (v as Map<String, dynamic>).map(
            (k, e) => MapEntry(k, Map<String, String>.from(e as Map)),
          ),
        ),
      );
      return val;
    });
