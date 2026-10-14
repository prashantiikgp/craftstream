import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/app/navigation_engine.dart';
import 'package:craftstream/schemas/app/navigation_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/app/navigation.yml';
NavigationSchema rules([String Function(String yaml)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, NavigationSchema.fromJson);
}

void main() {
  final engine = NavigationEngine(rules());

  test('Buy is 01 in orange, Sell is 02 in pink', () {
    expect(engine.role('buy').number, '01');
    expect(engine.role('buy').accent, 'orange');
    expect(engine.role('sell').number, '02');
    expect(engine.role('sell').accent, 'pink');
  });

  test('locations belong to a role', () {
    expect(engine.roleOf('/studio/new'), 'sell');
    expect(engine.roleOf('/discover?q=mug'), 'buy');
    expect(engine.roleOf('/placed/abc'), 'buy');
    expect(engine.roleOf('/'), isNull);
    expect(engine.roleOf('/studios'), isNull);
  });

  test('broken roles fail at load', () {
    expect(() => NavigationEngine(rules((y) => y.replaceFirst('number: "02"', 'number: "01"'))),
        throwsA(isA<NavigationRulesError>()));
    expect(() => NavigationEngine(rules((y) => y.replaceFirst('paths: [/studio]', 'paths: [/discover]'))),
        throwsA(isA<NavigationRulesError>()));
    expect(() => NavigationEngine(rules((y) => y.replaceFirst('home: /studio', 'home: studio'))),
        throwsA(isA<NavigationRulesError>()));
    expect(() => engine.role('rent'), throwsA(isA<NavigationRulesError>()));
  });
}
