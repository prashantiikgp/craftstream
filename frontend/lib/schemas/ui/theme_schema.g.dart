// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThemeSchema _$ThemeSchemaFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ThemeSchema',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'colors',
        'accents',
        'tones',
        'fonts',
        'styles',
        'spacing',
        'radius',
        'shadows',
        'motion',
        'focus',
        'contrast',
      ],
    );
    final val = ThemeSchema(
      colors: $checkedConvert(
        'colors',
        (v) => ModesSchema<ModeColorsSchema>.fromJson(
          v as Map<String, dynamic>,
          (value) => ModeColorsSchema.fromJson(value as Map<String, dynamic>),
        ),
      ),
      accents: $checkedConvert(
        'accents',
        (v) => ModesSchema<Map<String, AccentSchema>>.fromJson(
          v as Map<String, dynamic>,
          (value) => (value as Map<String, dynamic>).map(
            (k, e) =>
                MapEntry(k, AccentSchema.fromJson(e as Map<String, dynamic>)),
          ),
        ),
      ),
      tones: $checkedConvert(
        'tones',
        (v) => TonesSchema.fromJson(v as Map<String, dynamic>),
      ),
      fonts: $checkedConvert(
        'fonts',
        (v) => FontsSchema.fromJson(v as Map<String, dynamic>),
      ),
      styles: $checkedConvert(
        'styles',
        (v) => (v as Map<String, dynamic>).map(
          (k, e) =>
              MapEntry(k, TextStyleSchema.fromJson(e as Map<String, dynamic>)),
        ),
      ),
      spacing: $checkedConvert(
        'spacing',
        (v) => SpacingSchema.fromJson(v as Map<String, dynamic>),
      ),
      radius: $checkedConvert(
        'radius',
        (v) => RadiusSchema.fromJson(v as Map<String, dynamic>),
      ),
      shadows: $checkedConvert(
        'shadows',
        (v) => ModesSchema<ShadowSetSchema>.fromJson(
          v as Map<String, dynamic>,
          (value) => ShadowSetSchema.fromJson(value as Map<String, dynamic>),
        ),
      ),
      motion: $checkedConvert(
        'motion',
        (v) => MotionSchema.fromJson(v as Map<String, dynamic>),
      ),
      focus: $checkedConvert(
        'focus',
        (v) => FocusSchema.fromJson(v as Map<String, dynamic>),
      ),
      contrast: $checkedConvert(
        'contrast',
        (v) => ContrastSchema.fromJson(v as Map<String, dynamic>),
      ),
    );
    return val;
  },
);

ModesSchema<T> _$ModesSchemaFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => $checkedCreate('ModesSchema', json, ($checkedConvert) {
  $checkKeys(json, allowedKeys: const ['light', 'dark']);
  final val = ModesSchema<T>(
    light: $checkedConvert('light', (v) => fromJsonT(v)),
    dark: $checkedConvert('dark', (v) => fromJsonT(v)),
  );
  return val;
});

ModeColorsSchema _$ModeColorsSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ModeColorsSchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'ground',
            'surface',
            'surface_alt',
            'line',
            'line_strong',
            'text',
            'text_muted',
            'text_faint',
            'scrim',
            'on_scrim',
          ],
        );
        final val = ModeColorsSchema(
          ground: $checkedConvert('ground', (v) => v as String),
          surface: $checkedConvert('surface', (v) => v as String),
          surfaceAlt: $checkedConvert('surface_alt', (v) => v as String),
          line: $checkedConvert('line', (v) => v as String),
          lineStrong: $checkedConvert('line_strong', (v) => v as String),
          text: $checkedConvert('text', (v) => v as String),
          textMuted: $checkedConvert('text_muted', (v) => v as String),
          textFaint: $checkedConvert('text_faint', (v) => v as String),
          scrim: $checkedConvert('scrim', (v) => v as String),
          onScrim: $checkedConvert('on_scrim', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'surfaceAlt': 'surface_alt',
        'lineStrong': 'line_strong',
        'textMuted': 'text_muted',
        'textFaint': 'text_faint',
        'onScrim': 'on_scrim',
      },
    );

AccentSchema _$AccentSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AccentSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['fill', 'on_fill', 'ink', 'wash', 'line'],
      );
      final val = AccentSchema(
        fill: $checkedConvert('fill', (v) => v as String),
        onFill: $checkedConvert('on_fill', (v) => v as String),
        ink: $checkedConvert('ink', (v) => v as String),
        wash: $checkedConvert('wash', (v) => v as String),
        line: $checkedConvert('line', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'onFill': 'on_fill'});

TonesSchema _$TonesSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TonesSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'brand',
          'success',
          'danger',
          'info',
          'warning',
          'neutral',
        ],
      );
      final val = TonesSchema(
        brand: $checkedConvert('brand', (v) => v as String),
        success: $checkedConvert('success', (v) => v as String),
        danger: $checkedConvert('danger', (v) => v as String),
        info: $checkedConvert('info', (v) => v as String),
        warning: $checkedConvert('warning', (v) => v as String),
        neutral: $checkedConvert('neutral', (v) => v as String),
      );
      return val;
    });

FontsSchema _$FontsSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FontsSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['sans', 'mono']);
      final val = FontsSchema(
        sans: $checkedConvert('sans', (v) => v as String),
        mono: $checkedConvert('mono', (v) => v as String),
      );
      return val;
    });

TextStyleSchema _$TextStyleSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TextStyleSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'font',
          'size',
          'weight',
          'height',
          'tracking',
          'upper',
        ],
      );
      final val = TextStyleSchema(
        font: $checkedConvert('font', (v) => $enumDecode(_$FontKindEnumMap, v)),
        size: $checkedConvert('size', (v) => (v as num).toDouble()),
        weight: $checkedConvert('weight', (v) => (v as num).toInt()),
        height: $checkedConvert('height', (v) => (v as num).toDouble()),
        tracking: $checkedConvert('tracking', (v) => (v as num).toDouble()),
        upper: $checkedConvert('upper', (v) => v as bool? ?? false),
      );
      return val;
    });

const _$FontKindEnumMap = {FontKind.sans: 'sans', FontKind.mono: 'mono'};

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
      $checkKeys(json, allowedKeys: const ['none', 'sharp', 'card']);
      final val = RadiusSchema(
        none: $checkedConvert('none', (v) => (v as num).toDouble()),
        sharp: $checkedConvert('sharp', (v) => (v as num).toDouble()),
        card: $checkedConvert('card', (v) => (v as num).toDouble()),
      );
      return val;
    });

ShadowSetSchema _$ShadowSetSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ShadowSetSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['rest', 'lift', 'float']);
      final val = ShadowSetSchema(
        rest: $checkedConvert(
          'rest',
          (v) => (v as List<dynamic>)
              .map((e) => ShadowLayerSchema.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        lift: $checkedConvert(
          'lift',
          (v) => (v as List<dynamic>)
              .map((e) => ShadowLayerSchema.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        float: $checkedConvert(
          'float',
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

MotionSchema _$MotionSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'MotionSchema',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'durations',
        'curves',
        'reduced_motion_factor',
        'hover_lift',
        'door_hover_lift',
        'press_scale',
        'skeleton_pulse_ms',
        'skeleton_min_opacity',
      ],
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
      hoverLift: $checkedConvert('hover_lift', (v) => (v as num).toDouble()),
      doorHoverLift: $checkedConvert(
        'door_hover_lift',
        (v) => (v as num).toDouble(),
      ),
      pressScale: $checkedConvert('press_scale', (v) => (v as num).toDouble()),
      skeletonPulseMs: $checkedConvert(
        'skeleton_pulse_ms',
        (v) => (v as num).toInt(),
      ),
      skeletonMinOpacity: $checkedConvert(
        'skeleton_min_opacity',
        (v) => (v as num).toDouble(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'reducedMotionFactor': 'reduced_motion_factor',
    'hoverLift': 'hover_lift',
    'doorHoverLift': 'door_hover_lift',
    'pressScale': 'press_scale',
    'skeletonPulseMs': 'skeleton_pulse_ms',
    'skeletonMinOpacity': 'skeleton_min_opacity',
  },
);

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

FocusSchema _$FocusSchemaFromJson(Map<String, dynamic> json) => $checkedCreate(
  'FocusSchema',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const ['ring_width', 'ring_tone', 'min_target'],
    );
    final val = FocusSchema(
      ringWidth: $checkedConvert('ring_width', (v) => (v as num).toDouble()),
      ringTone: $checkedConvert('ring_tone', (v) => v as String),
      minTarget: $checkedConvert('min_target', (v) => (v as num).toDouble()),
    );
    return val;
  },
  fieldKeyMap: const {
    'ringWidth': 'ring_width',
    'ringTone': 'ring_tone',
    'minTarget': 'min_target',
  },
);

ContrastSchema _$ContrastSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ContrastSchema', json, ($checkedConvert) {
  $checkKeys(json, allowedKeys: const ['pairs', 'each_accent']);
  final val = ContrastSchema(
    pairs: $checkedConvert(
      'pairs',
      (v) => (v as List<dynamic>)
          .map((e) => ContrastPairSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    eachAccent: $checkedConvert(
      'each_accent',
      (v) => (v as List<dynamic>)
          .map((e) => ContrastPairSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
}, fieldKeyMap: const {'eachAccent': 'each_accent'});

ContrastPairSchema _$ContrastPairSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ContrastPairSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['fg', 'bg', 'min', 'why']);
      final val = ContrastPairSchema(
        fg: $checkedConvert('fg', (v) => v as String),
        bg: $checkedConvert('bg', (v) => v as String),
        min: $checkedConvert('min', (v) => (v as num).toDouble()),
        why: $checkedConvert('why', (v) => v as String),
      );
      return val;
    });
