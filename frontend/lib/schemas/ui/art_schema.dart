/// Shape of assets/config/ui/art.yml: backdrop shapes, door shapes and the poster generator.
library;

import 'package:json_annotation/json_annotation.dart';

part 'art_schema.g.dart';

@JsonSerializable()
class ArtSchema {
  final Map<String, List<ShapeSchema>> backdrops;
  final Map<String, List<ShapeSchema>> doors;
  final PosterSchema poster;

  const ArtSchema({required this.backdrops, required this.doors, required this.poster});

  factory ArtSchema.fromJson(Map<String, dynamic> json) => _$ArtSchemaFromJson(json);
}

@JsonEnum()
enum ShapeKind { circle, square, bar }

@JsonSerializable()
class ShapeSchema {
  final ShapeKind shape;
  final String accent;
  final double opacity;
  final double? size, w, h;
  final double? left, right, top, bottom;
  final double rotate;

  const ShapeSchema({
    required this.shape,
    required this.accent,
    this.opacity = 1,
    this.size,
    this.w,
    this.h,
    this.left,
    this.right,
    this.top,
    this.bottom,
    this.rotate = 0,
  });

  factory ShapeSchema.fromJson(Map<String, dynamic> json) => _$ShapeSchemaFromJson(json);
}

@JsonSerializable()
class PosterSchema {
  final List<String> colors;
  final PosterCircleSchema circle;
  final PosterBarSchema bar;

  const PosterSchema({required this.colors, required this.circle, required this.bar});

  factory PosterSchema.fromJson(Map<String, dynamic> json) => _$PosterSchemaFromJson(json);
}

@JsonSerializable()
class PosterCircleSchema {
  final List<double> size, x, y;

  const PosterCircleSchema({required this.size, required this.x, required this.y});

  factory PosterCircleSchema.fromJson(Map<String, dynamic> json) => _$PosterCircleSchemaFromJson(json);
}

@JsonSerializable()
class PosterBarSchema {
  final double thickness;
  final List<double> y, rotate;

  const PosterBarSchema({required this.thickness, required this.y, required this.rotate});

  factory PosterBarSchema.fromJson(Map<String, dynamic> json) => _$PosterBarSchemaFromJson(json);
}
