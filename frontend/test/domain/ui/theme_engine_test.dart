import 'dart:io';
import 'dart:ui';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/ui/theme_engine.dart';
import 'package:craftstream/schemas/ui/theme_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/ui/theme.yml';
ThemeSchema rules([String Function(String yaml)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, ThemeSchema.fromJson);
}

void main() {
  final engine = ThemeEngine(rules());

  test('theme B: light is #F5F5F5 grey, dark is near-black purple, accents are the same fills', () {
    expect(hexOf(engine.light.ground), '#F5F5F5');
    expect(hexOf(engine.dark.ground), '#0F0B18');
    expect(hexOf(engine.light.accent('orange').fill), '#FF6A2B');
    expect(hexOf(engine.dark.accent('orange').fill), '#FF6A2B');
    expect(engine.light.accents.keys, containsAll(['orange', 'pink', 'purple', 'marigold', 'neutral']));
  });

  test('tones name an accent', () {
    expect(engine.dark.tone('success').fill, engine.dark.accent('marigold').fill);
    expect(engine.dark.tone('danger').fill, engine.dark.accent('pink').fill);
    expect(() => engine.dark.tone('nope'), throwsA(isA<ThemeRulesError>()));
  });

  test('colour references resolve: plain names, accent parts and tone parts', () {
    final t = engine.light;
    expect(t.color('text_muted'), t.textMuted);
    expect(t.color('purple.ink'), t.accent('purple').ink);
    expect(t.color('success.fill'), t.tone('success').fill);
    expect(() => t.color('purple.glow'), throwsA(isA<ThemeRulesError>()));
  });

  test('both modes are readable (every check in theme.yml contrast)', () {
    final failures = engine.contrastFailures();
    expect(failures, isEmpty, reason: failures.join('\n'));
    expect(engine.contrastCheckCount, greaterThan(20));
  });

  test('an unreadable colour is caught', () {
    final bad = ThemeEngine(rules((y) => y.replaceFirst('text_muted: "#57506A"', 'text_muted: "#B0B0B0"')));
    expect(bad.contrastFailures().map((f) => '$f').join('\n'), contains('light: text_muted on ground'));
  });

  test('bad colours, unknown keys and unknown tones fail at load', () {
    expect(() => ThemeEngine(rules((y) => y.replaceFirst('ground: "#F5F5F5"', 'ground: "grey"'))),
        throwsA(isA<ThemeRulesError>().having((e) => e.message, 'message', contains('colors.light.ground'))));
    expect(() => rules((y) => y.replaceFirst('ground: "#F5F5F5"', 'ground: "#F5F5F5"\n    glow: "#000000"')),
        throwsA(isA<ConfigError>()));
    expect(() => ThemeEngine(rules((y) => y.replaceFirst('success: marigold', 'success: gold'))),
        throwsA(isA<ThemeRulesError>()));
  });

  test('type: Space Grotesk for text, Space Mono for eyebrows and prices, tracking in px', () {
    final t = engine.light;
    expect(t.styles['h1']!.family, 'SpaceGrotesk');
    expect(t.styles['eyebrow']!.family, 'SpaceMono');
    expect(t.styles['eyebrow']!.upper, isTrue);
    expect(t.styles['price']!.family, 'SpaceMono');
    expect(t.styles['h1']!.weight, FontWeight.w700);
    expect(t.styles['hero']!.letterSpacing, closeTo(-1.68, 0.001));
  });

  test('the key-card lift shadow takes the colour of what casts it', () {
    final pink = engine.dark.accent('pink').fill;
    final lift = engine.dark.lift(pink);
    expect(lift, hasLength(3));
    expect(lift.first.color.withValues(alpha: 1), pink);
    expect(engine.light.shadowRest, isEmpty);
  });

  test('sharp corners', () {
    final t = engine.light;
    expect(t.radius.sharp, 2);
    expect(t.radius.card, 4);
    expect(t.radius.named('none'), 0);
  });

  test('contrast maths matches WCAG reference values', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(contrastRatio(const Color(0xFFFE5722), const Color(0xFFFFFFFF)), closeTo(3.18, 0.02));
  });
}
