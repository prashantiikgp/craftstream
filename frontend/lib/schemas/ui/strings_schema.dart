/// Shape of assets/config/ui/strings.yml: every user-visible string, grouped by screen.
library;

import 'package:json_annotation/json_annotation.dart';

part 'strings_schema.g.dart';

@JsonSerializable()
class StringsSchema {
  final String locale;

  /// group -> key -> text. Text may hold `{placeholders}`.
  final Map<String, Map<String, String>> strings;

  const StringsSchema({required this.locale, required this.strings});

  factory StringsSchema.fromJson(Map<String, dynamic> json) => _$StringsSchemaFromJson(json);
}
