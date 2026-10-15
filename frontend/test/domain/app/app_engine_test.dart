import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/app/app_engine.dart';
import 'package:craftstream/schemas/app/app_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/app/app.yml';
AppSchema rules([String Function(String)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, AppSchema.fromJson);
}

void main() {
  final engine = AppEngine(rules());

  test('app.yml loads: the name, the first route and the starting theme', () {
    expect(engine.name, 'CraftStream');
    expect(engine.initialRoute, '/');
    expect(engine.themeMode, 'system');
  });

  test("a given theme mode replaces the file's", () {
    expect(AppEngine(rules(), themeMode: 'dark').themeMode, 'dark');
    expect(() => AppEngine(rules(), themeMode: 'sepia'), throwsA(isA<AppRulesError>()));
  });

  test('bad files are rejected', () {
    expect(
      () => AppEngine(rules((t) => t.replaceFirst('theme_mode: system', 'theme_mode: auto'))),
      throwsA(isA<AppRulesError>()),
    );
    expect(
      () => AppEngine(rules((t) => t.replaceFirst('initial_route: /', 'initial_route: home'))),
      throwsA(isA<AppRulesError>()),
    );
    expect(() => rules((t) => '$t\ntitle: Craft\n'), throwsA(isA<ConfigError>()));
  });
}
