import 'dart:io';

import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/ui/bricks_engine.dart';
import 'package:craftstream/schemas/ui/bricks_schema.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/harness.dart';

const path = 'assets/config/ui/bricks.yml';
BricksSchema rules([String Function(String yaml)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, BricksSchema.fromJson);
}

void main() {
  final engine = BricksEngine(rules());
  late BrickRefs refs;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = await testConfig();
    refs = brickRefs(
        theme: c.theme, strings: c.strings, routes: c.routes, navigation: c.navigation, icons: c.icons, art: c.art,
        layout: c.layout);
  });

  test('the catalogue loads; enums and defaults are typed', () {
    expect(engine.names, containsAll(['text', 'door', 'doors', 'receipt', 'order_card', 'button', 'spacer']));
    expect(engine.spec('button').props['variant']!.type, PropType.enumeration);
    expect(engine.spec('door').props['art']!.type, PropType.doorArt);
    expect(engine.style('door')['title'], 'hero');
  });

  test('a node gets its defaults, typed actions and parsed children', () {
    final n = engine.parse({
      'brick': 'button',
      'label': 'placed.see_orders',
      'action': {'go': '/placed/{item.id}'},
    }, 'test', refs);
    expect(n.need<String>('variant'), 'primary');
    expect(n.need<String>('tone'), 'brand');
    expect((n.need<ActionSpec>('action') as GoAction).template, '/placed/{item.id}');

    final list = engine.parse({
      'brick': 'list',
      'bind': 'orders.items',
      'item': {'brick': 'order_card', 'line': 'orders.line', 'number': 'orders.number'},
    }, 'test', refs);
    expect(list.need<BrickNode>('item').need<String>('bind'), 'item');
    expect(engine.textKeysOf(list.need<BrickNode>('item')), containsAll(['orders.line', 'orders.number']));
  });

  test('mistakes in a screen fail with where they are', () {
    void bad(Map<String, Object?> node, String fragment) => expect(
        () => engine.parse(node, 'home.body[3]', refs),
        throwsA(isA<BricksRulesError>().having((e) => e.message, 'message', allOf(contains('home.body[3]'), contains(fragment)))));
    bad({'brick': 'rocket'}, 'unknown brick');
    bad({'brick': 'text'}, '"text" is required');
    bad({'brick': 'text', 'text': 'home.nope'}, 'not in strings.yml');
    bad({'brick': 'text', 'text': 'home.tagline', 'colour': 'pink.ink'}, 'unknown prop "colour"');
    bad({'brick': 'text', 'text': 'home.tagline', 'style': 'giant'}, 'unknown text style');
    bad({'brick': 'mark', 'icon': 'rocket'}, 'unknown icon');
    bad({'brick': 'door', 'role': 'rent', 'title': 'home.buy_title', 'action': {'go': '/'}}, 'unknown role');
    bad({'brick': 'button', 'label': 'placed.see_orders', 'action': {'go': '/nowhere'}}, 'does not match any route');
    bad({'brick': 'button', 'label': 'placed.see_orders', 'action': {'jump': true}}, 'unknown action');
    bad({'brick': 'button', 'label': 'placed.see_orders', 'variant': 'fancy', 'action': {'back': true}}, 'not one of');
    bad({'brick': 'list', 'bind': 'Orders Items', 'item': {'brick': 'spacer'}}, 'not a data path');
  });

  test('a broken catalogue fails at load', () {
    expect(() => BricksEngine(rules((y) => y.replaceFirst('options: [primary, ghost], default: primary', 'default: primary'))),
        throwsA(isA<BricksRulesError>()));
    expect(() => BricksEngine(rules((y) => y.replaceFirst('options: [sm, lg], default: lg', 'options: [sm, lg], default: xl'))),
        throwsA(isA<BricksRulesError>()));
    expect(() => rules((y) => y.replaceFirst('type: role, required: true', 'type: person, required: true')),
        throwsA(isA<ConfigError>()));
  });
}
