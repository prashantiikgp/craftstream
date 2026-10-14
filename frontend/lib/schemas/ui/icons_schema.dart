/// Shape of assets/config/ui/icons.yml: line icons as SVG path data.
library;

import 'package:json_annotation/json_annotation.dart';

part 'icons_schema.g.dart';

@JsonSerializable()
class IconsSchema {
  final double viewBox;
  final double strokeWidth;
  final Map<String, IconSchema> icons;

  const IconsSchema({required this.viewBox, required this.strokeWidth, required this.icons});

  factory IconsSchema.fromJson(Map<String, dynamic> json) => _$IconsSchemaFromJson(json);
}

@JsonSerializable()
class IconSchema {
  final List<String> stroke;
  final List<String> fill;

  /// [cx, cy, r] per circle.
  final List<List<double>> circles;

  const IconSchema({this.stroke = const [], this.fill = const [], this.circles = const []});

  factory IconSchema.fromJson(Map<String, dynamic> json) => _$IconSchemaFromJson(json);
}
