// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orders_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrdersSchema _$OrdersSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'OrdersSchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const ['storage_key', 'keep', 'refresh_on_start'],
        );
        final val = OrdersSchema(
          storageKey: $checkedConvert('storage_key', (v) => v as String),
          keep: $checkedConvert('keep', (v) => (v as num).toInt()),
          refreshOnStart: $checkedConvert('refresh_on_start', (v) => v as bool),
        );
        return val;
      },
      fieldKeyMap: const {
        'storageKey': 'storage_key',
        'refreshOnStart': 'refresh_on_start',
      },
    );
