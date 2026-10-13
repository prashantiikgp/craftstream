// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeSchema _$ThemeSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ThemeSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'default_palette',
          'palettes',
          'surfaces',
          'semantic',
          'typography',
          'spacing',
          'radius',
          'elevation',
          'motion',
        ],
      );
      final val = ThemeSchema(
        defaultPalette: $checkedConvert('default_palette', (v) => v as String),
        palettes: $checkedConvert(
          'palettes',
          (v) => (v as Map<String, dynamic>).map(
            (k, e) =>
                MapEntry(k, PaletteSchema.fromJson(e as Map<String, dynamic>)),
          ),
        ),
        surfaces: $checkedConvert(
          'surfaces',
          (v) => SurfacesSchema.fromJson(v as Map<String, dynamic>),
        ),
        semantic: $checkedConvert(
          'semantic',
          (v) => SemanticsSchema.fromJson(v as Map<String, dynamic>),
        ),
        typography: $checkedConvert(
          'typography',
          (v) => TypographySchema.fromJson(v as Map<String, dynamic>),
        ),
        spacing: $checkedConvert(
          'spacing',
          (v) => SpacingSchema.fromJson(v as Map<String, dynamic>),
        ),
        radius: $checkedConvert(
          'radius',
          (v) => RadiusSchema.fromJson(v as Map<String, dynamic>),
        ),
        elevation: $checkedConvert(
          'elevation',
          (v) => ElevationSchema.fromJson(v as Map<String, dynamic>),
        ),
        motion: $checkedConvert(
          'motion',
          (v) => MotionSchema.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    }, fieldKeyMap: const {'defaultPalette': 'default_palette'});

PaletteSchema _$PaletteSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PaletteSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['label', 'light', 'dark']);
      final val = PaletteSchema(
        label: $checkedConvert('label', (v) => v as String),
        light: $checkedConvert(
          'light',
          (v) => PaletteColorsSchema.fromJson(v as Map<String, dynamic>),
        ),
        dark: $checkedConvert(
          'dark',
          (v) => PaletteColorsSchema.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

PaletteColorsSchema _$PaletteColorsSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PaletteColorsSchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'brand',
            'brand_d',
            'brand_dd',
            'brand_ink',
            'brand_l',
            'brand_ll',
            'brand_line',
            'on_brand',
            'secondary',
            'secondary_ink',
            'secondary_l',
            'on_secondary',
          ],
        );
        final val = PaletteColorsSchema(
          brand: $checkedConvert('brand', (v) => v as String),
          brandD: $checkedConvert('brand_d', (v) => v as String),
          brandDd: $checkedConvert('brand_dd', (v) => v as String),
          brandInk: $checkedConvert('brand_ink', (v) => v as String),
          brandL: $checkedConvert('brand_l', (v) => v as String),
          brandLl: $checkedConvert('brand_ll', (v) => v as String),
          brandLine: $checkedConvert('brand_line', (v) => v as String),
          onBrand: $checkedConvert('on_brand', (v) => v as String),
          secondary: $checkedConvert('secondary', (v) => v as String),
          secondaryInk: $checkedConvert('secondary_ink', (v) => v as String),
          secondaryL: $checkedConvert('secondary_l', (v) => v as String),
          onSecondary: $checkedConvert('on_secondary', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'brandD': 'brand_d',
        'brandDd': 'brand_dd',
        'brandInk': 'brand_ink',
        'brandL': 'brand_l',
        'brandLl': 'brand_ll',
        'brandLine': 'brand_line',
        'onBrand': 'on_brand',
        'secondaryInk': 'secondary_ink',
        'secondaryL': 'secondary_l',
        'onSecondary': 'on_secondary',
      },
    );

SurfacesSchema _$SurfacesSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SurfacesSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['light', 'dark']);
      final val = SurfacesSchema(
        light: $checkedConvert(
          'light',
          (v) => SurfaceColorsSchema.fromJson(v as Map<String, dynamic>),
        ),
        dark: $checkedConvert(
          'dark',
          (v) => SurfaceColorsSchema.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

SurfaceColorsSchema _$SurfaceColorsSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SurfaceColorsSchema', json, ($checkedConvert) {
  $checkKeys(
    json,
    allowedKeys: const [
      'bg',
      'card',
      'surface_soft',
      'hair',
      'hair_soft',
      'ink',
      'sub',
      'faint',
      'scrim',
    ],
  );
  final val = SurfaceColorsSchema(
    bg: $checkedConvert('bg', (v) => v as String),
    card: $checkedConvert('card', (v) => v as String),
    surfaceSoft: $checkedConvert('surface_soft', (v) => v as String),
    hair: $checkedConvert('hair', (v) => v as String),
    hairSoft: $checkedConvert('hair_soft', (v) => v as String),
    ink: $checkedConvert('ink', (v) => v as String),
    sub: $checkedConvert('sub', (v) => v as String),
    faint: $checkedConvert('faint', (v) => v as String),
    scrim: $checkedConvert('scrim', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'surfaceSoft': 'surface_soft', 'hairSoft': 'hair_soft'});

SemanticsSchema _$SemanticsSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SemanticsSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['light', 'dark']);
      final val = SemanticsSchema(
        light: $checkedConvert(
          'light',
          (v) => SemanticSetSchema.fromJson(v as Map<String, dynamic>),
        ),
        dark: $checkedConvert(
          'dark',
          (v) => SemanticSetSchema.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

SemanticSetSchema _$SemanticSetSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SemanticSetSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['success', 'danger', 'info', 'warning'],
      );
      final val = SemanticSetSchema(
        success: $checkedConvert(
          'success',
          (v) => StatusColorsSchema.fromJson(v as Map<String, dynamic>),
        ),
        danger: $checkedConvert(
          'danger',
          (v) => StatusColorsSchema.fromJson(v as Map<String, dynamic>),
        ),
        info: $checkedConvert(
          'info',
          (v) => StatusColorsSchema.fromJson(v as Map<String, dynamic>),
        ),
        warning: $checkedConvert(
          'warning',
          (v) => StatusColorsSchema.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

StatusColorsSchema _$StatusColorsSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('StatusColorsSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['fill', 'border', 'ink', 'wash']);
      final val = StatusColorsSchema(
        fill: $checkedConvert('fill', (v) => v as String),
        border: $checkedConvert('border', (v) => v as String),
        ink: $checkedConvert('ink', (v) => v as String),
        wash: $checkedConvert('wash', (v) => v as String),
      );
      return val;
    });

TypographySchema _$TypographySchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TypographySchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const ['heading_family', 'body_family', 'styles'],
        );
        final val = TypographySchema(
          headingFamily: $checkedConvert('heading_family', (v) => v as String),
          bodyFamily: $checkedConvert('body_family', (v) => v as String),
          styles: $checkedConvert(
            'styles',
            (v) => TypeScaleSchema.fromJson(v as Map<String, dynamic>),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'headingFamily': 'heading_family',
        'bodyFamily': 'body_family',
      },
    );

TypeScaleSchema _$TypeScaleSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TypeScaleSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'display',
          'h1',
          'h2',
          'h3',
          'title',
          'body',
          'body_strong',
          'label',
          'caption',
          'price',
        ],
      );
      final val = TypeScaleSchema(
        display: $checkedConvert(
          'display',
          (v) => TextStyleSchema.fromJson(v as Map<String, dynamic>),
        ),
        h1: $checkedConvert(
          'h1',
          (v) => TextStyleSchema.fromJson(v as Map<String, dynamic>),
        ),
        h2: $checkedConvert(
          'h2',
          (v) => TextStyleSchema.fromJson(v as Map<String, dynamic>),
        ),
        h3: $checkedConvert(
          'h3',
          (v) => TextStyleSchema.fromJson(v as Map<String, dynamic>),
        ),
        title: $checkedConvert(
          'title',
          (v) => TextStyleSchema.fromJson(v as Map<String, dynamic>),
        ),
        body: $checkedConvert(
          'body',
          (v) => TextStyleSchema.fromJson(v as Map<String, dynamic>),
        ),
        bodyStrong: $checkedConvert(
          'body_strong',
          (v) => TextStyleSchema.fromJson(v as Map<String, dynamic>),
        ),
        label: $checkedConvert(
          'label',
          (v) => TextStyleSchema.fromJson(v as Map<String, dynamic>),
        ),
        caption: $checkedConvert(
          'caption',
          (v) => TextStyleSchema.fromJson(v as Map<String, dynamic>),
        ),
        price: $checkedConvert(
          'price',
          (v) => TextStyleSchema.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    }, fieldKeyMap: const {'bodyStrong': 'body_strong'});

TextStyleSchema _$TextStyleSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TextStyleSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['family', 'size', 'weight', 'height', 'tracking'],
      );
      final val = TextStyleSchema(
        family: $checkedConvert(
          'family',
          (v) => $enumDecode(_$FontRoleEnumMap, v),
        ),
        size: $checkedConvert('size', (v) => (v as num).toDouble()),
        weight: $checkedConvert('weight', (v) => (v as num).toInt()),
        height: $checkedConvert('height', (v) => (v as num).toDouble()),
        tracking: $checkedConvert('tracking', (v) => (v as num).toDouble()),
      );
      return val;
    });

const _$FontRoleEnumMap = {FontRole.heading: 'heading', FontRole.body: 'body'};

SpacingSchema _$SpacingSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SpacingSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'xxs',
          'xs',
          'sm',
          'md',
          'lg',
          'xl',
          'xxl',
          'xxxl',
          'section',
        ],
      );
      final val = SpacingSchema(
        xxs: $checkedConvert('xxs', (v) => (v as num).toDouble()),
        xs: $checkedConvert('xs', (v) => (v as num).toDouble()),
        sm: $checkedConvert('sm', (v) => (v as num).toDouble()),
        md: $checkedConvert('md', (v) => (v as num).toDouble()),
        lg: $checkedConvert('lg', (v) => (v as num).toDouble()),
        xl: $checkedConvert('xl', (v) => (v as num).toDouble()),
        xxl: $checkedConvert('xxl', (v) => (v as num).toDouble()),
        xxxl: $checkedConvert('xxxl', (v) => (v as num).toDouble()),
        section: $checkedConvert('section', (v) => (v as num).toDouble()),
      );
      return val;
    });

RadiusSchema _$RadiusSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RadiusSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['tag', 'sm', 'md', 'lg', 'pill']);
      final val = RadiusSchema(
        tag: $checkedConvert('tag', (v) => (v as num).toDouble()),
        sm: $checkedConvert('sm', (v) => (v as num).toDouble()),
        md: $checkedConvert('md', (v) => (v as num).toDouble()),
        lg: $checkedConvert('lg', (v) => (v as num).toDouble()),
        pill: $checkedConvert('pill', (v) => (v as num).toDouble()),
      );
      return val;
    });

ElevationSchema _$ElevationSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ElevationSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['light', 'dark']);
      final val = ElevationSchema(
        light: $checkedConvert(
          'light',
          (v) => ElevationSetSchema.fromJson(v as Map<String, dynamic>),
        ),
        dark: $checkedConvert(
          'dark',
          (v) => ElevationSetSchema.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

ElevationSetSchema _$ElevationSetSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ElevationSetSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['sm', 'lg']);
      final val = ElevationSetSchema(
        sm: $checkedConvert(
          'sm',
          (v) => (v as List<dynamic>)
              .map((e) => ShadowLayerSchema.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        lg: $checkedConvert(
          'lg',
          (v) => (v as List<dynamic>)
              .map((e) => ShadowLayerSchema.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

ShadowLayerSchema _$ShadowLayerSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ShadowLayerSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['x', 'y', 'blur', 'spread', 'color', 'opacity'],
      );
      final val = ShadowLayerSchema(
        x: $checkedConvert('x', (v) => (v as num).toDouble()),
        y: $checkedConvert('y', (v) => (v as num).toDouble()),
        blur: $checkedConvert('blur', (v) => (v as num).toDouble()),
        spread: $checkedConvert('spread', (v) => (v as num).toDouble()),
        color: $checkedConvert('color', (v) => v as String),
        opacity: $checkedConvert('opacity', (v) => (v as num).toDouble()),
      );
      return val;
    });

MotionSchema _$MotionSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MotionSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['durations', 'curves', 'reduced_motion_factor'],
      );
      final val = MotionSchema(
        durations: $checkedConvert(
          'durations',
          (v) => DurationsSchema.fromJson(v as Map<String, dynamic>),
        ),
        curves: $checkedConvert(
          'curves',
          (v) => CurvesSchema.fromJson(v as Map<String, dynamic>),
        ),
        reducedMotionFactor: $checkedConvert(
          'reduced_motion_factor',
          (v) => (v as num).toDouble(),
        ),
      );
      return val;
    }, fieldKeyMap: const {'reducedMotionFactor': 'reduced_motion_factor'});

DurationsSchema _$DurationsSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DurationsSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['fast', 'medium', 'slow']);
      final val = DurationsSchema(
        fast: $checkedConvert('fast', (v) => (v as num).toInt()),
        medium: $checkedConvert('medium', (v) => (v as num).toInt()),
        slow: $checkedConvert('slow', (v) => (v as num).toInt()),
      );
      return val;
    });

CurvesSchema _$CurvesSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CurvesSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['smooth', 'out', 'in', 'spring']);
      final val = CurvesSchema(
        smooth: $checkedConvert(
          'smooth',
          (v) =>
              (v as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        ),
        out: $checkedConvert(
          'out',
          (v) =>
              (v as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        ),
        inCurve: $checkedConvert(
          'in',
          (v) =>
              (v as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        ),
        spring: $checkedConvert(
          'spring',
          (v) =>
              (v as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        ),
      );
      return val;
    }, fieldKeyMap: const {'inCurve': 'in'});
