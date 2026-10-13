/// Design tokens: resolve theme.yml for one palette + brightness into concrete values. Pure Dart (dart:ui only).
///
///   final engine = ThemeEngine(rules);            // validates every colour of every palette up front
///   final tokens = engine.resolve('saffron', Brightness.light);
///   engine.contrastFailures()                     // WCAG checks for every palette, used by tests and /catalog
library;

import 'dart:math' as math;
import 'dart:ui';

import '../../schemas/ui/theme_schema.dart';

class ThemeRulesError implements Exception {
  final String message;
  const ThemeRulesError(this.message);
  @override
  String toString() => 'theme.yml: $message';
}

/// "#RRGGBB" -> opaque Color. Anything else is a rules error naming the token.
Color parseHex(String hex, String token) {
  final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex);
  if (m == null) throw ThemeRulesError('$token: "$hex" is not a #RRGGBB colour');
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

/// WCAG 2.x contrast ratio between two opaque colours (1.0 – 21.0).
double contrastRatio(Color a, Color b) {
  double channel(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) => 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a), lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

String hexOf(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class StatusColors {
  final Color fill, border, ink, wash;
  const StatusColors({required this.fill, required this.border, required this.ink, required this.wash});
}

class ShadowSpec {
  final Offset offset;
  final double blur, spread;
  final Color color;
  const ShadowSpec({required this.offset, required this.blur, required this.spread, required this.color});
}

class TextSpec {
  final String family;
  final double size, height, letterSpacing;
  final FontWeight weight;
  const TextSpec({
    required this.family,
    required this.size,
    required this.weight,
    required this.height,
    required this.letterSpacing,
  });
}

/// Every token, resolved for one palette and brightness.
class DesignTokens {
  final String palette;
  final String paletteLabel;
  final Brightness brightness;
  // brand + secondary
  final Color brand, brandD, brandDd, brandInk, brandL, brandLl, brandLine, onBrand;
  final Color secondary, secondaryInk, secondaryL, onSecondary;
  // surfaces + text
  final Color bg, card, surfaceSoft, hair, hairSoft, ink, sub, faint, scrim;
  // status
  final StatusColors success, danger, info, warning;
  // type, space, shape, depth, motion
  final Map<String, TextSpec> text;
  final SpacingSchema space;
  final RadiusSchema radius;
  final List<ShadowSpec> shadowSm, shadowLg;
  final Duration fast, medium, slow;
  final Map<String, List<double>> curves;
  final double reducedMotionFactor;

  const DesignTokens({
    required this.palette,
    required this.paletteLabel,
    required this.brightness,
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
    required this.bg,
    required this.card,
    required this.surfaceSoft,
    required this.hair,
    required this.hairSoft,
    required this.ink,
    required this.sub,
    required this.faint,
    required this.scrim,
    required this.success,
    required this.danger,
    required this.info,
    required this.warning,
    required this.text,
    required this.space,
    required this.radius,
    required this.shadowSm,
    required this.shadowLg,
    required this.fast,
    required this.medium,
    required this.slow,
    required this.curves,
    required this.reducedMotionFactor,
  });

  /// Named colours, for the catalog and for contrast checks.
  Map<String, Color> get namedColors => {
        'brand': brand, 'brand_d': brandD, 'brand_dd': brandDd, 'brand_ink': brandInk, 'brand_l': brandL,
        'brand_ll': brandLl, 'brand_line': brandLine, 'on_brand': onBrand,
        'secondary': secondary, 'secondary_ink': secondaryInk, 'secondary_l': secondaryL,
        'on_secondary': onSecondary,
        'bg': bg, 'card': card, 'surface_soft': surfaceSoft, 'hair': hair, 'hair_soft': hairSoft,
        'ink': ink, 'sub': sub, 'faint': faint, 'scrim': scrim,
      };
}

/// A text/background pair that must stay readable, with its WCAG threshold.
class ContrastRule {
  final String fg, bg;
  final double min;
  final String why;
  const ContrastRule(this.fg, this.bg, this.min, this.why);
}

class ContrastFailure {
  final String palette;
  final Brightness brightness;
  final ContrastRule rule;
  final double actual;
  const ContrastFailure(this.palette, this.brightness, this.rule, this.actual);
  @override
  String toString() => '$palette/${brightness.name}: ${rule.fg} on ${rule.bg} is ${actual.toStringAsFixed(2)}:1, '
      'needs ${rule.min}:1 (${rule.why})';
}

/// 4.5 = normal text (WCAG AA), 3.0 = large text and UI components (button fills with 16 px semibold labels).
const contrastRules = <ContrastRule>[
  ContrastRule('ink', 'bg', 7.0, 'body text'),
  ContrastRule('ink', 'card', 7.0, 'body text on cards'),
  ContrastRule('sub', 'bg', 4.5, 'secondary text'),
  ContrastRule('sub', 'card', 4.5, 'secondary text on cards'),
  ContrastRule('brand_ink', 'bg', 4.5, 'orange text'),
  ContrastRule('brand_ink', 'card', 4.5, 'orange text on cards'),
  ContrastRule('brand_ink', 'brand_ll', 4.5, 'active nav / selected chip'),
  ContrastRule('on_brand', 'brand', 3.0, 'primary button label'),
  ContrastRule('on_brand', 'brand_d', 3.0, 'primary button label, hovered'),
  ContrastRule('secondary_ink', 'bg', 4.5, 'secondary-coloured text'),
  ContrastRule('secondary_ink', 'secondary_l', 4.5, 'tag text on its tint'),
  ContrastRule('on_secondary', 'secondary', 3.0, 'secondary button label'),
];

class ThemeEngine {
  final ThemeSchema rules;

  /// Validates the whole file: default palette exists, every colour parses, curves have 4 points.
  ThemeEngine(this.rules) {
    if (!rules.palettes.containsKey(rules.defaultPalette)) {
      throw ThemeRulesError('default_palette "${rules.defaultPalette}" is not in palettes');
    }
    for (final name in rules.palettes.keys) {
      for (final b in Brightness.values) {
        resolve(name, b);
      }
    }
    for (final MapEntry(:key, :value) in _curves.entries) {
      if (value.length != 4) throw ThemeRulesError('motion.curves.$key needs 4 numbers');
    }
  }

  List<String> get paletteNames => rules.palettes.keys.toList();

  String labelOf(String palette) => rules.palettes[palette]?.label ?? palette;

  Map<String, List<double>> get _curves => {
        'smooth': rules.motion.curves.smooth,
        'out': rules.motion.curves.out,
        'in': rules.motion.curves.inCurve,
        'spring': rules.motion.curves.spring,
      };

  DesignTokens resolve(String palette, Brightness brightness) {
    final p = rules.palettes[palette];
    if (p == null) throw ThemeRulesError('unknown palette "$palette" (have: ${paletteNames.join(', ')})');
    final dark = brightness == Brightness.dark;
    final pc = dark ? p.dark : p.light;
    final s = dark ? rules.surfaces.dark : rules.surfaces.light;
    final sem = dark ? rules.semantic.dark : rules.semantic.light;
    final el = dark ? rules.elevation.dark : rules.elevation.light;
    final mode = dark ? 'dark' : 'light';
    Color c(String hex, String token) => parseHex(hex, token);
    StatusColors status(StatusColorsSchema x, String n) => StatusColors(
          fill: c(x.fill, 'semantic.$mode.$n.fill'),
          border: c(x.border, 'semantic.$mode.$n.border'),
          ink: c(x.ink, 'semantic.$mode.$n.ink'),
          wash: c(x.wash, 'semantic.$mode.$n.wash'),
        );
    List<ShadowSpec> shadows(List<ShadowLayerSchema> layers, String level) => [
          for (final (i, l) in layers.indexed)
            ShadowSpec(
              offset: Offset(l.x, l.y),
              blur: l.blur,
              spread: l.spread,
              color: c(l.color, 'elevation.$mode.$level[$i].color').withValues(alpha: l.opacity),
            ),
        ];
    final t = rules.typography;
    TextSpec text(TextStyleSchema x) => TextSpec(
          family: x.family == FontRole.heading ? t.headingFamily : t.bodyFamily,
          size: x.size,
          weight: FontWeight.values.firstWhere((w) => w.value == x.weight,
              orElse: () => throw ThemeRulesError('font weight ${x.weight} must be 100..900 in steps of 100')),
          height: x.height,
          letterSpacing: x.tracking * x.size,
        );
    final st = t.styles;
    final pre = 'palettes.$palette.$mode';
    return DesignTokens(
      palette: palette,
      paletteLabel: p.label,
      brightness: brightness,
      brand: c(pc.brand, '$pre.brand'),
      brandD: c(pc.brandD, '$pre.brand_d'),
      brandDd: c(pc.brandDd, '$pre.brand_dd'),
      brandInk: c(pc.brandInk, '$pre.brand_ink'),
      brandL: c(pc.brandL, '$pre.brand_l'),
      brandLl: c(pc.brandLl, '$pre.brand_ll'),
      brandLine: c(pc.brandLine, '$pre.brand_line'),
      onBrand: c(pc.onBrand, '$pre.on_brand'),
      secondary: c(pc.secondary, '$pre.secondary'),
      secondaryInk: c(pc.secondaryInk, '$pre.secondary_ink'),
      secondaryL: c(pc.secondaryL, '$pre.secondary_l'),
      onSecondary: c(pc.onSecondary, '$pre.on_secondary'),
      bg: c(s.bg, 'surfaces.$mode.bg'),
      card: c(s.card, 'surfaces.$mode.card'),
      surfaceSoft: c(s.surfaceSoft, 'surfaces.$mode.surface_soft'),
      hair: c(s.hair, 'surfaces.$mode.hair'),
      hairSoft: c(s.hairSoft, 'surfaces.$mode.hair_soft'),
      ink: c(s.ink, 'surfaces.$mode.ink'),
      sub: c(s.sub, 'surfaces.$mode.sub'),
      faint: c(s.faint, 'surfaces.$mode.faint'),
      scrim: c(s.scrim, 'surfaces.$mode.scrim'),
      success: status(sem.success, 'success'),
      danger: status(sem.danger, 'danger'),
      info: status(sem.info, 'info'),
      warning: status(sem.warning, 'warning'),
      text: {
        'display': text(st.display), 'h1': text(st.h1), 'h2': text(st.h2), 'h3': text(st.h3),
        'title': text(st.title), 'body': text(st.body), 'body_strong': text(st.bodyStrong),
        'label': text(st.label), 'caption': text(st.caption), 'price': text(st.price),
      },
      space: rules.spacing,
      radius: rules.radius,
      shadowSm: shadows(el.sm, 'sm'),
      shadowLg: shadows(el.lg, 'lg'),
      fast: Duration(milliseconds: rules.motion.durations.fast),
      medium: Duration(milliseconds: rules.motion.durations.medium),
      slow: Duration(milliseconds: rules.motion.durations.slow),
      curves: _curves,
      reducedMotionFactor: rules.motion.reducedMotionFactor,
    );
  }

  /// Every readability problem across all palettes and both brightnesses (empty = all good).
  List<ContrastFailure> contrastFailures() => [
        for (final name in paletteNames)
          for (final b in Brightness.values) ...checkContrast(resolve(name, b)),
      ];

  static List<ContrastFailure> checkContrast(DesignTokens t) {
    final colors = t.namedColors;
    final failures = <ContrastFailure>[];
    for (final rule in contrastRules) {
      final ratio = contrastRatio(colors[rule.fg]!, colors[rule.bg]!);
      if (ratio < rule.min) failures.add(ContrastFailure(t.palette, t.brightness, rule, ratio));
    }
    for (final (name, s) in [('success', t.success), ('danger', t.danger), ('info', t.info), ('warning', t.warning)]) {
      final ratio = contrastRatio(s.ink, s.wash);
      if (ratio < 4.5) {
        failures.add(ContrastFailure(t.palette, t.brightness, ContrastRule('$name.ink', '$name.wash', 4.5, 'status text'),
            ratio));
      }
    }
    return failures;
  }
}
