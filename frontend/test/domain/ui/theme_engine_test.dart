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

  test('theme.yml loads and every palette resolves in light and dark', () {
    expect(engine.paletteNames, containsAll(['saffron', 'terracotta', 'marigold']));
    for (final p in engine.paletteNames) {
      for (final b in Brightness.values) {
        expect(engine.resolve(p, b).palette, p);
      }
    }
  });

  test('saffron light is the Fluno orange', () {
    final t = engine.resolve('saffron', Brightness.light);
    expect(hexOf(t.brand), '#FE5722');
    expect(hexOf(t.brandInk), '#C2410C');
    expect(hexOf(t.bg), '#FAF6F4');
  });

  test('every palette is readable in light and dark (WCAG)', () {
    final failures = engine.contrastFailures();
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('a palette that makes text unreadable is caught', () {
    final bad = ThemeEngine(rules((y) => y.replaceFirst('brand_ink: "#C2410C"', 'brand_ink: "#FF9966"')));
    final failures = bad.contrastFailures().map((f) => f.toString()).join('\n');
    expect(failures, contains('saffron/light: brand_ink on bg'));
  });

  test('bad colours, unknown keys and a missing default palette fail at load', () {
    expect(() => ThemeEngine(rules((y) => y.replaceFirst('brand: "#FE5722"', 'brand: "orange"'))),
        throwsA(isA<ThemeRulesError>().having((e) => e.message, 'message', contains('palettes.saffron.light.brand'))));
    expect(() => rules((y) => y.replaceFirst('brand_d: "#E64A19"', 'brand_d: "#E64A19"\n      brand_x: "#000000"')),
        throwsA(isA<ConfigError>()));
    expect(() => ThemeEngine(rules((y) => y.replaceFirst('default_palette: saffron', 'default_palette: neon'))),
        throwsA(isA<ThemeRulesError>()));
  });

  test('type scale resolves families, weights and tracking in px', () {
    final t = engine.resolve('saffron', Brightness.light);
    expect(t.text['h1']!.family, 'Poppins');
    expect(t.text['body']!.family, 'Inter');
    expect(t.text['h1']!.weight, FontWeight.w700);
    expect(t.text['display']!.letterSpacing, closeTo(-0.68, 0.001));
  });

  test('contrast maths matches WCAG reference values', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(contrastRatio(const Color(0xFFFE5722), const Color(0xFFFFFFFF)), closeTo(3.18, 0.02));
  });
}
