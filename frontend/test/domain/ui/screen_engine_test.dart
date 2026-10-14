import 'dart:io';

import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/ui/bricks_engine.dart';
import 'package:craftstream/domain/ui/screen_engine.dart';
import 'package:craftstream/schemas/ui/screen_schema.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/harness.dart';

Map<String, ScreenSchema> screens([String Function(String name, String yaml)? edit]) => {
      for (final f in Directory('assets/config/ui/screens').listSync().whereType<File>())
        if (f.path.endsWith('.yml'))
          f.uri.pathSegments.last.replaceAll('.yml', ''): parseYaml(
              edit == null ? f.readAsStringSync() : edit(f.uri.pathSegments.last, f.readAsStringSync()),
              f.path,
              ScreenSchema.fromJson),
    };

void main() {
  late AppConfig c;
  late BrickRefs refs;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    c = await testConfig();
    refs = brickRefs(
        theme: c.theme, strings: c.strings, routes: c.routes, navigation: c.navigation, icons: c.icons, art: c.art,
        layout: c.layout);
  });

  ScreenEngine engine([String Function(String name, String yaml)? edit]) =>
      ScreenEngine(screens(edit), c.bricks, refs, backdrops: c.art.backdropNames.toSet());

  test('home, placed and orders load as brick trees', () {
    final e = engine();
    expect(e.names, containsAll(['home', 'placed', 'orders']));
    final home = e.screen('home');
    expect(home.fill, isTrue);
    expect(home.backdrop, 'home');
    final doors = home.body.firstWhere((b) => b.brick == 'doors').need<List<BrickNode>>('items');
    expect(doors.map((d) => d.need<String>('role')), ['buy', 'sell']);
    expect(e.screen('orders').allBricks.map((b) => b.brick), contains('order_card'));
    expect(e.screen('placed').empty.single.brick, 'empty_state');
  });

  test('every screen routes.yml shows exists, and every screen is routed', () {
    expect(c.routes.screenNames, everyElement(isIn(c.screens.names)));
    expect(c.screens.names, everyElement(isIn(c.routes.screenNames)));
  });

  test('broken screens fail at load with the file and position', () {
    expect(() => engine((name, y) => name == 'home.yml' ? y.replaceFirst('backdrop: home', 'backdrop: space') : y),
        throwsA(isA<ScreenRulesError>()));
    expect(() => engine((name, y) => name == 'orders.yml' ? y.replaceFirst('gap: md\n', 'gap: huge\n') : y),
        throwsA(isA<ScreenRulesError>()));
    expect(() => engine((name, y) => name == 'orders.yml' ? y.replaceFirst('- brick: list', '- brick: spacer\n  - brick: list') : y),
        throwsA(isA<ScreenRulesError>().having((e) => e.message, 'message', contains('fill: true'))));
    expect(() => engine((name, y) => name == 'home.yml' ? y.replaceFirst('label: home.orders', 'label: home.order') : y),
        throwsA(isA<BricksRulesError>().having((e) => e.message, 'message', contains('home.body[2]'))));
    expect(() => screens((name, y) => name == 'home.yml' ? y.replaceFirst('fill: true', 'fill: true\nfil: true') : y),
        throwsA(isA<ConfigError>()));
  });
}
