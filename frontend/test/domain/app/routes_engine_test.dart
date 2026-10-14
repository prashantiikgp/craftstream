import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/app/routes_engine.dart';
import 'package:craftstream/schemas/app/routes_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/app/routes.yml';
RoutesSchema rules([String Function(String yaml)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, RoutesSchema.fromJson);
}

void main() {
  final engine = RoutesEngine(rules());

  test('routes.yml loads; nested paths are joined and their parameters listed', () {
    expect(engine.initial, '/');
    final buy = engine.entries.firstWhere((e) => e.path == '/product/:id/buy');
    expect(buy.screen, 'checkout');
    expect(buy.params, ['id']);
    expect(engine.screenNames, containsAll(['home', 'orders', 'placed']));
  });

  test('concrete locations and go: templates match routes', () {
    expect(engine.match('/placed/3129d7a45f42')?.screen, 'placed');
    expect(engine.match('/product/p_01/buy')?.screen, 'checkout');
    expect(engine.match('/discover?q=mug')?.screen, 'discover');
    expect(engine.match('/nowhere'), isNull);
    expect(engine.acceptsTemplate('/placed/{item.id}'), isTrue);
    expect(engine.acceptsTemplate('/placed/{item.id}/more'), isFalse);
  });

  test('broken routes fail at load', () {
    expect(() => RoutesEngine(rules((y) => y.replaceFirst('initial: /', 'initial: /start'))),
        throwsA(isA<RoutesRulesError>()));
    expect(() => RoutesEngine(rules((y) => y.replaceFirst('    screen: home', '    screen: home\n    legacy: x'))),
        throwsA(isA<RoutesRulesError>()));
    expect(() => RoutesEngine(rules((y) => y.replaceFirst('- path: buy', '- path: /buy'))),
        throwsA(isA<RoutesRulesError>()));
    expect(() => RoutesEngine(rules((y) => y.replaceFirst('path: /orders', 'path: /'))),
        throwsA(isA<RoutesRulesError>()));
    expect(() => rules((y) => y.replaceFirst('shell: true', 'shel: true')), throwsA(isA<ConfigError>()));
  });
}
