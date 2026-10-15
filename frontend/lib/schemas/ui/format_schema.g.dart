// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'format_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FormatSchema _$FormatSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FormatSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['money', 'bytes', 'duration', 'date', 'time'],
      );
      final val = FormatSchema(
        money: $checkedConvert(
          'money',
          (v) => MoneyFormatSchema.fromJson(v as Map<String, dynamic>),
        ),
        bytes: $checkedConvert(
          'bytes',
          (v) => BytesFormatSchema.fromJson(v as Map<String, dynamic>),
        ),
        duration: $checkedConvert(
          'duration',
          (v) => DurationFormatSchema.fromJson(v as Map<String, dynamic>),
        ),
        date: $checkedConvert('date', (v) => v as String),
        time: $checkedConvert('time', (v) => v as String),
      );
      return val;
    });

MoneyFormatSchema _$MoneyFormatSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'MoneyFormatSchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'minus',
            'thousands',
            'decimal_point',
            'decimals',
            'hide_zero_fraction',
            'currencies',
            'other',
          ],
        );
        final val = MoneyFormatSchema(
          minus: $checkedConvert('minus', (v) => v as String),
          thousands: $checkedConvert('thousands', (v) => v as String),
          decimalPoint: $checkedConvert('decimal_point', (v) => v as String),
          decimals: $checkedConvert('decimals', (v) => (v as num).toInt()),
          hideZeroFraction: $checkedConvert(
            'hide_zero_fraction',
            (v) => v as bool,
          ),
          currencies: $checkedConvert(
            'currencies',
            (v) => (v as Map<String, dynamic>).map(
              (k, e) => MapEntry(
                k,
                CurrencyFormatSchema.fromJson(e as Map<String, dynamic>),
              ),
            ),
          ),
          other: $checkedConvert(
            'other',
            (v) => CurrencyFormatSchema.fromJson(v as Map<String, dynamic>),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'decimalPoint': 'decimal_point',
        'hideZeroFraction': 'hide_zero_fraction',
      },
    );

CurrencyFormatSchema _$CurrencyFormatSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CurrencyFormatSchema', json, ($checkedConvert) {
  $checkKeys(json, allowedKeys: const ['symbol', 'grouping']);
  final val = CurrencyFormatSchema(
    symbol: $checkedConvert('symbol', (v) => v as String),
    grouping: $checkedConvert(
      'grouping',
      (v) => (v as List<dynamic>).map((e) => (e as num).toInt()).toList(),
    ),
  );
  return val;
});

BytesFormatSchema _$BytesFormatSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BytesFormatSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['base', 'pattern', 'units']);
      final val = BytesFormatSchema(
        base: $checkedConvert('base', (v) => (v as num).toInt()),
        pattern: $checkedConvert('pattern', (v) => v as String),
        units: $checkedConvert(
          'units',
          (v) => (v as List<dynamic>)
              .map((e) => ByteUnitSchema.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

ByteUnitSchema _$ByteUnitSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ByteUnitSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['unit', 'power', 'decimals']);
      final val = ByteUnitSchema(
        unit: $checkedConvert('unit', (v) => v as String),
        power: $checkedConvert('power', (v) => (v as num).toInt()),
        decimals: $checkedConvert('decimals', (v) => (v as num).toInt()),
      );
      return val;
    });

DurationFormatSchema _$DurationFormatSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DurationFormatSchema', json, ($checkedConvert) {
  $checkKeys(json, allowedKeys: const ['short', 'long']);
  final val = DurationFormatSchema(
    short: $checkedConvert('short', (v) => v as String),
    long: $checkedConvert('long', (v) => v as String),
  );
  return val;
});
