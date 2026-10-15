/// Shape of assets/config/ui/format.yml: how money, file sizes, video lengths, dates and times are written.
library;

import 'package:json_annotation/json_annotation.dart';

part 'format_schema.g.dart';

@JsonSerializable()
class FormatSchema {
  final MoneyFormatSchema money;
  final BytesFormatSchema bytes;
  final DurationFormatSchema duration;
  final String date;
  final String time;

  const FormatSchema({
    required this.money,
    required this.bytes,
    required this.duration,
    required this.date,
    required this.time,
  });

  factory FormatSchema.fromJson(Map<String, dynamic> json) => _$FormatSchemaFromJson(json);
}

@JsonSerializable()
class MoneyFormatSchema {
  final String minus;
  final String thousands;
  final String decimalPoint;
  final int decimals;
  final bool hideZeroFraction;

  /// By ISO code (`INR`).
  final Map<String, CurrencyFormatSchema> currencies;

  /// A currency not listed; `{code}` in its symbol is the currency code.
  final CurrencyFormatSchema other;

  const MoneyFormatSchema({
    required this.minus,
    required this.thousands,
    required this.decimalPoint,
    required this.decimals,
    required this.hideZeroFraction,
    required this.currencies,
    required this.other,
  });

  factory MoneyFormatSchema.fromJson(Map<String, dynamic> json) => _$MoneyFormatSchemaFromJson(json);
}

@JsonSerializable()
class CurrencyFormatSchema {
  final String symbol;

  /// Digit group sizes from the right; the last one repeats.
  final List<int> grouping;

  const CurrencyFormatSchema({required this.symbol, required this.grouping});

  factory CurrencyFormatSchema.fromJson(Map<String, dynamic> json) => _$CurrencyFormatSchemaFromJson(json);
}

@JsonSerializable()
class BytesFormatSchema {
  final int base;
  final String pattern;
  final List<ByteUnitSchema> units;

  const BytesFormatSchema({required this.base, required this.pattern, required this.units});

  factory BytesFormatSchema.fromJson(Map<String, dynamic> json) => _$BytesFormatSchemaFromJson(json);
}

@JsonSerializable()
class ByteUnitSchema {
  final String unit;
  final int power;
  final int decimals;

  const ByteUnitSchema({required this.unit, required this.power, required this.decimals});

  factory ByteUnitSchema.fromJson(Map<String, dynamic> json) => _$ByteUnitSchemaFromJson(json);
}

@JsonSerializable()
class DurationFormatSchema {
  final String short;
  final String long;

  const DurationFormatSchema({required this.short, required this.long});

  factory DurationFormatSchema.fromJson(Map<String, dynamic> json) => _$DurationFormatSchemaFromJson(json);
}
