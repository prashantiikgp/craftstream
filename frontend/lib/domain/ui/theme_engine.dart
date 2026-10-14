/// Design tokens: resolve theme.yml for light or dark into concrete values. Pure Dart (dart:ui only).
///
///   final engine = ThemeEngine(rules);            // validates every colour, reference and tone up front
///   final tokens = engine.resolve(Brightness.dark);
///   tokens.tone('success').fill                   // a meaning -> its accent's colours
///   engine.contrastFailures()                     // the WCAG checks listed in theme.yml, both modes
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

/// One accent's colours (see theme.yml `accents`).
class AccentColors {
  final Color fill, onFill, ink, wash, line;
  const AccentColors({required this.fill, required this.onFill, required this.ink, required this.wash, required this.line});

  Map<String, Color> get parts => {'fill': fill, 'on_fill': onFill, 'ink': ink, 'wash': wash, 'line': line};
}

/// v1 status quartet, kept for v1 widgets until they are replaced (theme.yml `legacy`).
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
  final bool upper;
  const TextSpec({
    required this.family,
    required this.size,
    required this.weight,
    required this.height,
    required this.letterSpacing,
    this.upper = false,
  });
}

/// Corner radii: theme B names plus the v1 names they stand in for.
class Radii {
  final double none, sharp, card;
  final double tag, sm, md, lg, pill; // v1
  const Radii({
    required this.none,
    required this.sharp,
    required this.card,
    required this.tag,
    required this.sm,
    required this.md,
    required this.lg,
    required this.pill,
  });

  double named(String name) =>
      {'none': none, 'sharp': sharp, 'card': card}[name] ?? (throw ThemeRulesError('unknown radius "$name"'));
}

/// Every token, resolved for one brightness.
class DesignTokens {
  final Brightness brightness;
  // ground and text
  final Color ground, surface, surfaceAlt, line, lineStrong, text, textMuted, textFaint, scrim;
  final Map<String, AccentColors> accents;
  final Map<String, String> _tones;
  // type, space, shape, depth, motion, focus
  final Map<String, TextSpec> styles;
  final SpacingSchema space;
  final Radii radius;
  final List<ShadowSpec> shadowRest, shadowFloat;
  final List<ShadowLayerSchema> _lift;
  final Duration fast, medium, slow, skeletonPulse;
  final Map<String, List<double>> curves;
  final double reducedMotionFactor, hoverLift, doorHoverLift, pressScale, skeletonMinOpacity;
  final double focusRingWidth, minTarget;
  final String focusRingTone;
  // v1 names (theme.yml `legacy`)
  final Color brand, brandD, brandDd, brandInk, brandL, brandLl, brandLine, onBrand;
  final Color secondary, secondaryInk, secondaryL, onSecondary;
  final Color bg, card, surfaceSoft, hair, hairSoft, ink, sub, faint;

  const DesignTokens({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.scrim,
    required this.accents,
    required Map<String, String> tones,
    required this.styles,
    required this.space,
    required this.radius,
    required this.shadowRest,
    required this.shadowFloat,
    required List<ShadowLayerSchema> lift,
    required this.fast,
    required this.medium,
    required this.slow,
    required this.skeletonPulse,
    required this.curves,
    required this.reducedMotionFactor,
    required this.hoverLift,
    required this.doorHoverLift,
    required this.pressScale,
    required this.skeletonMinOpacity,
    required this.focusRingWidth,
    required this.focusRingTone,
    required this.minTarget,
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
  })  : _tones = tones,
        _lift = lift;

  bool get isDark => brightness == Brightness.dark;

  Iterable<String> get toneNames => _tones.keys;

  AccentColors accent(String name) => accents[name] ?? (throw ThemeRulesError('unknown accent "$name"'));

  /// A meaning (`success`, `danger` …) -> the colours of the accent theme.yml gives it.
  AccentColors tone(String name) =>
      accent(_tones[name] ?? (throw ThemeRulesError('unknown tone "$name" (have: ${_tones.keys.join(', ')})')));

  /// The key-card shadow for something whose own colour is [accent].
  List<ShadowSpec> lift(Color accent) => [
        for (final l in _lift)
          ShadowSpec(
            offset: Offset(l.x, l.y),
            blur: l.blur,
            spread: l.spread,
            color: (l.color == 'accent' ? accent : parseHex(l.color, 'shadows.lift')).withValues(alpha: l.opacity),
          ),
      ];

  // v1 shadow and status names.
  List<ShadowSpec> get shadowSm => shadowRest;
  List<ShadowSpec> get shadowLg => lift(tone('brand').fill);
  StatusColors _status(String tone) {
    final a = this.tone(tone);
    return StatusColors(fill: a.fill, border: a.line, ink: a.ink, wash: a.wash);
  }

  StatusColors get success => _status('success');
  StatusColors get danger => _status('danger');
  StatusColors get info => _status('info');
  StatusColors get warning => _status('warning');

  /// Every colour by the name theme.yml uses for it: `ground`, `text`, `orange.fill`, `pink.ink` …
  Map<String, Color> get namedColors => {
        'ground': ground, 'surface': surface, 'surface_alt': surfaceAlt, 'line': line, 'line_strong': lineStrong,
        'text': text, 'text_muted': textMuted, 'text_faint': textFaint, 'scrim': scrim,
        for (final MapEntry(key: name, value: a) in accents.entries)
          for (final MapEntry(key: part, value: c) in a.parts.entries) '$name.$part': c,
      };

  /// A colour reference from YAML (`text_muted`, `purple.ink`, or a tone part like `success.fill`).
  Color color(String ref) {
    final named = namedColors[ref];
    if (named != null) return named;
    final dot = ref.indexOf('.');
    if (dot > 0 && _tones.containsKey(ref.substring(0, dot))) {
      final part = tone(ref.substring(0, dot)).parts[ref.substring(dot + 1)];
      if (part != null) return part;
    }
    throw ThemeRulesError('unknown colour "$ref"');
  }
}

class ContrastFailure {
  final Brightness brightness;
  final String fg, bg, why;
  final double min, actual;
  const ContrastFailure(this.brightness, this.fg, this.bg, this.min, this.actual, this.why);
  @override
  String toString() =>
      '${brightness.name}: $fg on $bg is ${actual.toStringAsFixed(2)}:1, needs $min:1 ($why)';
}

/// Text styles the v1 widgets read by field name (TypeStyles in app_theme.dart).
const requiredStyles = ['display', 'h1', 'h2', 'h3', 'title', 'body', 'body_strong', 'label', 'caption', 'price'];

/// v1 colour names the v1 widgets read (DesignTokens fields above).
const requiredLegacyColors = [
  'brand', 'brand_d', 'brand_dd', 'brand_ink', 'brand_l', 'brand_ll', 'brand_line', 'on_brand',
  'secondary', 'secondary_ink', 'secondary_l', 'on_secondary',
  'bg', 'card', 'surface_soft', 'hair', 'hair_soft', 'ink', 'sub', 'faint',
];
const requiredLegacyRadii = ['tag', 'sm', 'md', 'lg', 'pill'];

class ThemeEngine {
  final ThemeSchema rules;
  late final DesignTokens light = _resolve(Brightness.light);
  late final DesignTokens dark = _resolve(Brightness.dark);

  /// Validates the whole file: colours parse, both modes have the same accents, tones and references resolve,
  /// curves have 4 points and the styles the app needs exist.
  ThemeEngine(this.rules) {
    final lightAccents = rules.accents.light.keys.toSet(), darkAccents = rules.accents.dark.keys.toSet();
    if (lightAccents.length != darkAccents.length || !lightAccents.containsAll(darkAccents)) {
      throw const ThemeRulesError('accents.light and accents.dark must name the same accents');
    }
    for (final MapEntry(:key, :value) in _toneMap.entries) {
      if (!lightAccents.contains(value)) throw ThemeRulesError('tones.$key: "$value" is not an accent');
    }
    if (!_toneMap.containsKey(rules.focus.ringTone)) {
      throw ThemeRulesError('focus.ring_tone: "${rules.focus.ringTone}" is not a tone');
    }
    for (final name in requiredStyles) {
      if (!rules.styles.containsKey(name)) throw ThemeRulesError('styles.$name is missing');
    }
    for (final MapEntry(:key, :value) in _curves.entries) {
      if (value.length != 4) throw ThemeRulesError('motion.curves.$key needs 4 numbers');
    }
    if (rules.motion.pressScale <= 0 || rules.motion.pressScale > 1) {
      throw const ThemeRulesError('motion.press_scale must be in (0, 1]');
    }
    for (final name in requiredLegacyColors) {
      if (!rules.legacy.colors.containsKey(name)) throw ThemeRulesError('legacy.colors.$name is missing');
    }
    for (final name in requiredLegacyRadii) {
      if (!rules.legacy.radius.containsKey(name)) throw ThemeRulesError('legacy.radius.$name is missing');
    }
    light;
    dark;
    for (final t in [light, dark]) {
      for (final p in [...rules.contrast.pairs, ...rules.contrast.eachAccent]) {
        if (rules.contrast.eachAccent.contains(p)) {
          for (final a in t.accents.values) {
            if (!a.parts.containsKey(p.fg) && !t.namedColors.containsKey(p.fg)) _badRef('contrast.each_accent', p.fg);
            if (!a.parts.containsKey(p.bg) && !t.namedColors.containsKey(p.bg)) _badRef('contrast.each_accent', p.bg);
          }
        } else {
          t.color(p.fg);
          t.color(p.bg);
        }
      }
    }
  }

  static Never _badRef(String where, String ref) => throw ThemeRulesError('$where: unknown colour "$ref"');

  Map<String, String> get _toneMap => {
        'brand': rules.tones.brand,
        'success': rules.tones.success,
        'danger': rules.tones.danger,
        'info': rules.tones.info,
        'warning': rules.tones.warning,
        'neutral': rules.tones.neutral,
      };

  Map<String, List<double>> get _curves => {
        'smooth': rules.motion.curves.smooth,
        'out': rules.motion.curves.out,
        'in': rules.motion.curves.inCurve,
        'spring': rules.motion.curves.spring,
      };

  DesignTokens resolve(Brightness brightness) => brightness == Brightness.dark ? dark : light;

  DesignTokens _resolve(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final mode = isDark ? 'dark' : 'light';
    final c = isDark ? rules.colors.dark : rules.colors.light;
    final shadows = isDark ? rules.shadows.dark : rules.shadows.light;
    Color hex(String v, String token) => parseHex(v, token);

    final accents = {
      for (final MapEntry(key: name, value: a) in (isDark ? rules.accents.dark : rules.accents.light).entries)
        name: AccentColors(
          fill: hex(a.fill, 'accents.$mode.$name.fill'),
          onFill: hex(a.onFill, 'accents.$mode.$name.on_fill'),
          ink: hex(a.ink, 'accents.$mode.$name.ink'),
          wash: hex(a.wash, 'accents.$mode.$name.wash'),
          line: hex(a.line, 'accents.$mode.$name.line'),
        ),
    };
    final base = <String, Color>{
      'ground': hex(c.ground, 'colors.$mode.ground'),
      'surface': hex(c.surface, 'colors.$mode.surface'),
      'surface_alt': hex(c.surfaceAlt, 'colors.$mode.surface_alt'),
      'line': hex(c.line, 'colors.$mode.line'),
      'line_strong': hex(c.lineStrong, 'colors.$mode.line_strong'),
      'text': hex(c.text, 'colors.$mode.text'),
      'text_muted': hex(c.textMuted, 'colors.$mode.text_muted'),
      'text_faint': hex(c.textFaint, 'colors.$mode.text_faint'),
      'scrim': hex(c.scrim, 'colors.$mode.scrim'),
    };
    Color ref(String r, String where) {
      if (base.containsKey(r)) return base[r]!;
      final dot = r.indexOf('.');
      final part = dot > 0 ? accents[r.substring(0, dot)]?.parts[r.substring(dot + 1)] : null;
      return part ?? _badRef(where, r);
    }

    final legacy = {
      for (final MapEntry(:key, :value) in rules.legacy.colors.entries) key: ref(value, 'legacy.colors.$key'),
    };
    final radius = rules.radius;
    double r(String name, String where) =>
        {'none': radius.none, 'sharp': radius.sharp, 'card': radius.card}[name] ??
        (throw ThemeRulesError('$where: unknown radius "$name"'));
    List<ShadowSpec> layers(List<ShadowLayerSchema> ls, String level) => [
          for (final (i, l) in ls.indexed)
            ShadowSpec(
              offset: Offset(l.x, l.y),
              blur: l.blur,
              spread: l.spread,
              color: hex(l.color, 'shadows.$mode.$level[$i].color').withValues(alpha: l.opacity),
            ),
        ];
    for (final (i, l) in shadows.lift.indexed) {
      if (l.color != 'accent') hex(l.color, 'shadows.$mode.lift[$i].color');
    }
    TextSpec text(String name, TextStyleSchema x) => TextSpec(
          family: x.font == FontKind.mono ? rules.fonts.mono : rules.fonts.sans,
          size: x.size,
          weight: FontWeight.values.firstWhere((w) => w.value == x.weight,
              orElse: () => throw ThemeRulesError('styles.$name: weight ${x.weight} must be 100..900 in steps of 100')),
          height: x.height,
          letterSpacing: x.tracking * x.size,
          upper: x.upper,
        );
    final m = rules.motion;
    return DesignTokens(
      brightness: brightness,
      ground: base['ground']!,
      surface: base['surface']!,
      surfaceAlt: base['surface_alt']!,
      line: base['line']!,
      lineStrong: base['line_strong']!,
      text: base['text']!,
      textMuted: base['text_muted']!,
      textFaint: base['text_faint']!,
      scrim: base['scrim']!,
      accents: accents,
      tones: _toneMap,
      styles: {for (final MapEntry(:key, :value) in rules.styles.entries) key: text(key, value)},
      space: rules.spacing,
      radius: Radii(
        none: radius.none,
        sharp: radius.sharp,
        card: radius.card,
        tag: r(rules.legacy.radius['tag']!, 'legacy.radius.tag'),
        sm: r(rules.legacy.radius['sm']!, 'legacy.radius.sm'),
        md: r(rules.legacy.radius['md']!, 'legacy.radius.md'),
        lg: r(rules.legacy.radius['lg']!, 'legacy.radius.lg'),
        pill: r(rules.legacy.radius['pill']!, 'legacy.radius.pill'),
      ),
      shadowRest: layers(shadows.rest, 'rest'),
      shadowFloat: layers(shadows.float, 'float'),
      lift: shadows.lift,
      fast: Duration(milliseconds: m.durations.fast),
      medium: Duration(milliseconds: m.durations.medium),
      slow: Duration(milliseconds: m.durations.slow),
      skeletonPulse: Duration(milliseconds: m.skeletonPulseMs),
      curves: _curves,
      reducedMotionFactor: m.reducedMotionFactor,
      hoverLift: m.hoverLift,
      doorHoverLift: m.doorHoverLift,
      pressScale: m.pressScale,
      skeletonMinOpacity: m.skeletonMinOpacity,
      focusRingWidth: rules.focus.ringWidth,
      focusRingTone: rules.focus.ringTone,
      minTarget: rules.focus.minTarget,
      brand: legacy['brand']!,
      brandD: legacy['brand_d']!,
      brandDd: legacy['brand_dd']!,
      brandInk: legacy['brand_ink']!,
      brandL: legacy['brand_l']!,
      brandLl: legacy['brand_ll']!,
      brandLine: legacy['brand_line']!,
      onBrand: legacy['on_brand']!,
      secondary: legacy['secondary']!,
      secondaryInk: legacy['secondary_ink']!,
      secondaryL: legacy['secondary_l']!,
      onSecondary: legacy['on_secondary']!,
      bg: legacy['bg']!,
      card: legacy['card']!,
      surfaceSoft: legacy['surface_soft']!,
      hair: legacy['hair']!,
      hairSoft: legacy['hair_soft']!,
      ink: legacy['ink']!,
      sub: legacy['sub']!,
      faint: legacy['faint']!,
    );
  }

  /// Number of colour pairs checked per mode (for /catalog).
  int get contrastCheckCount =>
      rules.contrast.pairs.length + rules.contrast.eachAccent.length * rules.accents.light.length;

  /// Every readability problem in both modes (empty = all good).
  List<ContrastFailure> contrastFailures() => [...checkContrast(light), ...checkContrast(dark)];

  List<ContrastFailure> checkContrast(DesignTokens t) {
    final failures = <ContrastFailure>[];
    void check(String fgName, Color fg, String bgName, Color bg, double min, String why) {
      final ratio = contrastRatio(fg, bg);
      if (ratio < min) failures.add(ContrastFailure(t.brightness, fgName, bgName, min, ratio, why));
    }

    for (final p in rules.contrast.pairs) {
      check(p.fg, t.color(p.fg), p.bg, t.color(p.bg), p.min, p.why);
    }
    for (final MapEntry(key: name, value: a) in t.accents.entries) {
      Color pick(String ref) => a.parts[ref] ?? t.color(ref);
      String label(String ref) => a.parts.containsKey(ref) ? '$name.$ref' : ref;
      for (final p in rules.contrast.eachAccent) {
        check(label(p.fg), pick(p.fg), label(p.bg), pick(p.bg), p.min, p.why);
      }
    }
    return failures;
  }
}
