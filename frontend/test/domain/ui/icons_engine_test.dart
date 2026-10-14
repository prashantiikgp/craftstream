import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/ui/icons_engine.dart';
import 'package:craftstream/schemas/ui/icons_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/ui/icons.yml';
IconsSchema rules([String Function(String yaml)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, IconsSchema.fromJson);
}

void main() {
  final engine = IconsEngine(rules());

  test('icons.yml parses; the screens\' icons exist', () {
    expect(engine.names, containsAll(['back', 'arrow', 'orders', 'check', 'sun', 'moon', 'play', 'search']));
    expect(engine.shape('search').circles.single.r, 7);
    expect(engine.shape('play').fill, hasLength(1));
  });

  test('relative commands become absolute; H, V and implicit repeats work', () {
    final back = parsePath('M15 5l-7 7 7 7', 'back');
    expect(back.whereType<LineTo>().map((l) => (l.x, l.y)), [(8.0, 12.0), (15.0, 19.0)]);
    final box = parsePath('M3 6h13v12H3z', 'video');
    expect(box.whereType<LineTo>().map((l) => (l.x, l.y)), [(16.0, 6.0), (16.0, 18.0), (3.0, 18.0)]);
    expect(box.last, isA<ClosePath>());
    final dot = parsePath('M12 16h.01', 'info');
    expect((dot.last as LineTo).x, closeTo(12.01, 1e-9));
    final curve = parsePath('M0 0C1 1 2 2 3 3 4 4 5 5 6 6', 'c');
    expect(curve.whereType<CubicTo>(), hasLength(2));
  });

  test('broken icons fail at load with their name', () {
    expect(() => IconsEngine(rules((y) => y.replaceFirst('M15 5l-7 7 7 7', 'M15 5a7 7 0 0 1 7 7'))),
        throwsA(isA<IconsRulesError>().having((e) => e.message, 'message', contains('back'))));
    expect(() => IconsEngine(rules((y) => y.replaceFirst('M15 5l-7 7 7 7', 'l-7 7'))), throwsA(isA<IconsRulesError>()));
    expect(() => IconsEngine(rules((y) => y.replaceFirst('[[11, 11, 7]]', '[[11, 11]]'))), throwsA(isA<IconsRulesError>()));
    expect(() => engine.shape('rocket'), throwsA(isA<IconsRulesError>()));
  });
}
