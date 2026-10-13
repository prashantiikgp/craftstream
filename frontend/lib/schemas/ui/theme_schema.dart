/// Shape of assets/config/ui/theme.yml: the design tokens. Unknown or missing keys fail at startup.
library;

import 'package:json_annotation/json_annotation.dart';

part 'theme_schema.g.dart';

@JsonSerializable()
class ThemeSchema {
  final String defaultPalette;
  final Map<String, PaletteSchema> palettes;
  final SurfacesSchema surfaces;
  final SemanticsSchema semantic;
  final TypographySchema typography;
  final SpacingSchema spacing;
  final RadiusSchema radius;
  final ElevationSchema elevation;
  final MotionSchema motion;

  const ThemeSchema({
    required this.defaultPalette,
    required this.palettes,
    required this.surfaces,
    required this.semantic,
    required this.typography,
    required this.spacing,
    required this.radius,
    required this.elevation,
    required this.motion,
  });

  factory ThemeSchema.fromJson(Map<String, dynamic> json) => _$ThemeSchemaFromJson(json);
}

@JsonSerializable()
class PaletteSchema {
  final String label;
  final PaletteColorsSchema light;
  final PaletteColorsSchema dark;

  const PaletteSchema({required this.label, required this.light, required this.dark});

  factory PaletteSchema.fromJson(Map<String, dynamic> json) => _$PaletteSchemaFromJson(json);
}

@JsonSerializable()
class PaletteColorsSchema {
  final String brand;
  final String brandD;
  final String brandDd;
  final String brandInk;
  final String brandL;
  final String brandLl;
  final String brandLine;
  final String onBrand;
  final String secondary;
  final String secondaryInk;
  final String secondaryL;
  final String onSecondary;

  const PaletteColorsSchema({
    required this.brand,
    required this.brandD,
    required this.brandDd,
    required this.brandInk,
    required this.brandL,
    required this.brandLl,
    required this.brandLine,
    required this.onBrand,
    required this.secondary,
    required this.secondaryInk,
    required this.secondaryL,
    required this.onSecondary,
  });

  factory PaletteColorsSchema.fromJson(Map<String, dynamic> json) => _$PaletteColorsSchemaFromJson(json);
}

@JsonSerializable()
class SurfacesSchema {
  final SurfaceColorsSchema light;
  final SurfaceColorsSchema dark;

  const SurfacesSchema({required this.light, required this.dark});

  factory SurfacesSchema.fromJson(Map<String, dynamic> json) => _$SurfacesSchemaFromJson(json);
}

@JsonSerializable()
class SurfaceColorsSchema {
  final String bg;
  final String card;
  final String surfaceSoft;
  final String hair;
  final String hairSoft;
  final String ink;
  final String sub;
  final String faint;
  final String scrim;

  const SurfaceColorsSchema({
    required this.bg,
    required this.card,
    required this.surfaceSoft,
    required this.hair,
    required this.hairSoft,
    required this.ink,
    required this.sub,
    required this.faint,
    required this.scrim,
  });

  factory SurfaceColorsSchema.fromJson(Map<String, dynamic> json) => _$SurfaceColorsSchemaFromJson(json);
}

@JsonSerializable()
class SemanticsSchema {
  final SemanticSetSchema light;
  final SemanticSetSchema dark;

  const SemanticsSchema({required this.light, required this.dark});

  factory SemanticsSchema.fromJson(Map<String, dynamic> json) => _$SemanticsSchemaFromJson(json);
}

@JsonSerializable()
class SemanticSetSchema {
  final StatusColorsSchema success;
  final StatusColorsSchema danger;
  final StatusColorsSchema info;
  final StatusColorsSchema warning;

  const SemanticSetSchema({required this.success, required this.danger, required this.info, required this.warning});

  factory SemanticSetSchema.fromJson(Map<String, dynamic> json) => _$SemanticSetSchemaFromJson(json);
}

@JsonSerializable()
class StatusColorsSchema {
  final String fill;
  final String border;
  final String ink;
  final String wash;

  const StatusColorsSchema({required this.fill, required this.border, required this.ink, required this.wash});

  factory StatusColorsSchema.fromJson(Map<String, dynamic> json) => _$StatusColorsSchemaFromJson(json);
}

@JsonEnum()
enum FontRole { heading, body }

@JsonSerializable()
class TypographySchema {
  final String headingFamily;
  final String bodyFamily;
  final TypeScaleSchema styles;

  const TypographySchema({required this.headingFamily, required this.bodyFamily, required this.styles});

  factory TypographySchema.fromJson(Map<String, dynamic> json) => _$TypographySchemaFromJson(json);
}

@JsonSerializable()
class TypeScaleSchema {
  final TextStyleSchema display;
  final TextStyleSchema h1;
  final TextStyleSchema h2;
  final TextStyleSchema h3;
  final TextStyleSchema title;
  final TextStyleSchema body;
  final TextStyleSchema bodyStrong;
  final TextStyleSchema label;
  final TextStyleSchema caption;
  final TextStyleSchema price;

  const TypeScaleSchema({
    required this.display,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.title,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
    required this.price,
  });

  factory TypeScaleSchema.fromJson(Map<String, dynamic> json) => _$TypeScaleSchemaFromJson(json);
}

@JsonSerializable()
class TextStyleSchema {
  final FontRole family;
  final double size;
  final int weight;
  final double height;
  final double tracking;

  const TextStyleSchema({
    required this.family,
    required this.size,
    required this.weight,
    required this.height,
    required this.tracking,
  });

  factory TextStyleSchema.fromJson(Map<String, dynamic> json) => _$TextStyleSchemaFromJson(json);
}

@JsonSerializable()
class SpacingSchema {
  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;
  final double section;

  const SpacingSchema({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.xxxl,
    required this.section,
  });

  factory SpacingSchema.fromJson(Map<String, dynamic> json) => _$SpacingSchemaFromJson(json);
}

@JsonSerializable()
class RadiusSchema {
  final double tag;
  final double sm;
  final double md;
  final double lg;
  final double pill;

  const RadiusSchema({required this.tag, required this.sm, required this.md, required this.lg, required this.pill});

  factory RadiusSchema.fromJson(Map<String, dynamic> json) => _$RadiusSchemaFromJson(json);
}

@JsonSerializable()
class ElevationSchema {
  final ElevationSetSchema light;
  final ElevationSetSchema dark;

  const ElevationSchema({required this.light, required this.dark});

  factory ElevationSchema.fromJson(Map<String, dynamic> json) => _$ElevationSchemaFromJson(json);
}

@JsonSerializable()
class ElevationSetSchema {
  final List<ShadowLayerSchema> sm;
  final List<ShadowLayerSchema> lg;

  const ElevationSetSchema({required this.sm, required this.lg});

  factory ElevationSetSchema.fromJson(Map<String, dynamic> json) => _$ElevationSetSchemaFromJson(json);
}

@JsonSerializable()
class ShadowLayerSchema {
  final double x;
  final double y;
  final double blur;
  final double spread;
  final String color;
  final double opacity;

  const ShadowLayerSchema({
    required this.x,
    required this.y,
    required this.blur,
    required this.spread,
    required this.color,
    required this.opacity,
  });

  factory ShadowLayerSchema.fromJson(Map<String, dynamic> json) => _$ShadowLayerSchemaFromJson(json);
}

@JsonSerializable()
class MotionSchema {
  final DurationsSchema durations;
  final CurvesSchema curves;
  final double reducedMotionFactor;

  const MotionSchema({required this.durations, required this.curves, required this.reducedMotionFactor});

  factory MotionSchema.fromJson(Map<String, dynamic> json) => _$MotionSchemaFromJson(json);
}

@JsonSerializable()
class DurationsSchema {
  final int fast;
  final int medium;
  final int slow;

  const DurationsSchema({required this.fast, required this.medium, required this.slow});

  factory DurationsSchema.fromJson(Map<String, dynamic> json) => _$DurationsSchemaFromJson(json);
}

@JsonSerializable()
class CurvesSchema {
  final List<double> smooth;
  final List<double> out;
  @JsonKey(name: 'in')
  final List<double> inCurve;
  final List<double> spring;

  const CurvesSchema({required this.smooth, required this.out, required this.inCurve, required this.spring});

  factory CurvesSchema.fromJson(Map<String, dynamic> json) => _$CurvesSchemaFromJson(json);
}
