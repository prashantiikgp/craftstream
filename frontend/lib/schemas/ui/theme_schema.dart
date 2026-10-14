/// Shape of assets/config/ui/theme.yml: theme B's design tokens. Unknown or missing keys fail at startup.
library;

import 'package:json_annotation/json_annotation.dart';

part 'theme_schema.g.dart';

@JsonSerializable()
class ThemeSchema {
  final ModesSchema<ModeColorsSchema> colors;
  final ModesSchema<Map<String, AccentSchema>> accents;
  final TonesSchema tones;
  final FontsSchema fonts;
  final Map<String, TextStyleSchema> styles;
  final SpacingSchema spacing;
  final RadiusSchema radius;
  final ModesSchema<ShadowSetSchema> shadows;
  final MotionSchema motion;
  final FocusSchema focus;
  final ContrastSchema contrast;
  final LegacySchema legacy;

  const ThemeSchema({
    required this.colors,
    required this.accents,
    required this.tones,
    required this.fonts,
    required this.styles,
    required this.spacing,
    required this.radius,
    required this.shadows,
    required this.motion,
    required this.focus,
    required this.contrast,
    required this.legacy,
  });

  factory ThemeSchema.fromJson(Map<String, dynamic> json) => _$ThemeSchemaFromJson(json);
}

/// A value given once for light mode and once for dark mode.
@JsonSerializable(genericArgumentFactories: true)
class ModesSchema<T> {
  final T light;
  final T dark;

  const ModesSchema({required this.light, required this.dark});

  factory ModesSchema.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$ModesSchemaFromJson(json, fromJsonT);
}

@JsonSerializable()
class ModeColorsSchema {
  final String ground;
  final String surface;
  final String surfaceAlt;
  final String line;
  final String lineStrong;
  final String text;
  final String textMuted;
  final String textFaint;
  final String scrim;

  const ModeColorsSchema({
    required this.ground,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.scrim,
  });

  factory ModeColorsSchema.fromJson(Map<String, dynamic> json) => _$ModeColorsSchemaFromJson(json);
}

@JsonSerializable()
class AccentSchema {
  final String fill;
  final String onFill;
  final String ink;
  final String wash;
  final String line;

  const AccentSchema({
    required this.fill,
    required this.onFill,
    required this.ink,
    required this.wash,
    required this.line,
  });

  factory AccentSchema.fromJson(Map<String, dynamic> json) => _$AccentSchemaFromJson(json);
}

/// Meaning -> accent name.
@JsonSerializable()
class TonesSchema {
  final String brand;
  final String success;
  final String danger;
  final String info;
  final String warning;
  final String neutral;

  const TonesSchema({
    required this.brand,
    required this.success,
    required this.danger,
    required this.info,
    required this.warning,
    required this.neutral,
  });

  factory TonesSchema.fromJson(Map<String, dynamic> json) => _$TonesSchemaFromJson(json);
}

@JsonEnum()
enum FontKind { sans, mono }

@JsonSerializable()
class FontsSchema {
  final String sans;
  final String mono;

  const FontsSchema({required this.sans, required this.mono});

  factory FontsSchema.fromJson(Map<String, dynamic> json) => _$FontsSchemaFromJson(json);
}

@JsonSerializable()
class TextStyleSchema {
  final FontKind font;
  final double size;
  final int weight;
  final double height;
  final double tracking;
  final bool upper;

  const TextStyleSchema({
    required this.font,
    required this.size,
    required this.weight,
    required this.height,
    required this.tracking,
    this.upper = false,
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
  final double none;
  final double sharp;
  final double card;

  const RadiusSchema({required this.none, required this.sharp, required this.card});

  factory RadiusSchema.fromJson(Map<String, dynamic> json) => _$RadiusSchemaFromJson(json);
}

@JsonSerializable()
class ShadowSetSchema {
  final List<ShadowLayerSchema> rest;
  final List<ShadowLayerSchema> lift;
  final List<ShadowLayerSchema> float;

  const ShadowSetSchema({required this.rest, required this.lift, required this.float});

  factory ShadowSetSchema.fromJson(Map<String, dynamic> json) => _$ShadowSetSchemaFromJson(json);
}

@JsonSerializable()
class ShadowLayerSchema {
  final double x;
  final double y;
  final double blur;
  final double spread;

  /// "#RRGGBB", or `accent` for the colour of whatever casts the shadow.
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
  final double hoverLift;
  final double doorHoverLift;
  final double pressScale;
  final int skeletonPulseMs;
  final double skeletonMinOpacity;

  const MotionSchema({
    required this.durations,
    required this.curves,
    required this.reducedMotionFactor,
    required this.hoverLift,
    required this.doorHoverLift,
    required this.pressScale,
    required this.skeletonPulseMs,
    required this.skeletonMinOpacity,
  });

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

@JsonSerializable()
class FocusSchema {
  final double ringWidth;
  final String ringTone;
  final double minTarget;

  const FocusSchema({required this.ringWidth, required this.ringTone, required this.minTarget});

  factory FocusSchema.fromJson(Map<String, dynamic> json) => _$FocusSchemaFromJson(json);
}

@JsonSerializable()
class ContrastSchema {
  final List<ContrastPairSchema> pairs;
  final List<ContrastPairSchema> eachAccent;

  const ContrastSchema({required this.pairs, required this.eachAccent});

  factory ContrastSchema.fromJson(Map<String, dynamic> json) => _$ContrastSchemaFromJson(json);
}

@JsonSerializable()
class ContrastPairSchema {
  final String fg;
  final String bg;
  final double min;
  final String why;

  const ContrastPairSchema({required this.fg, required this.bg, required this.min, required this.why});

  factory ContrastPairSchema.fromJson(Map<String, dynamic> json) => _$ContrastPairSchemaFromJson(json);
}

/// v1 token names -> theme B references (`ground`, `orange.ink` …). Temporary; see theme.yml.
@JsonSerializable()
class LegacySchema {
  final Map<String, String> colors;
  final Map<String, String> radius;

  const LegacySchema({required this.colors, required this.radius});

  factory LegacySchema.fromJson(Map<String, dynamic> json) => _$LegacySchemaFromJson(json);
}
