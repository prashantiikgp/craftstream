import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/ui/art_engine.dart';
import 'package:craftstream/schemas/ui/art_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/ui/art.yml';
ArtSchema rules([String Function(String yaml)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, ArtSchema.fromJson);
}

void main() {
  final engine = ArtEngine(rules());

  test('art.yml loads: home and placed backdrops, buy and sell doors', () {
    expect(engine.backdropNames, containsAll(['home', 'placed']));
    expect(engine.doorNames, containsAll(['buy', 'sell']));
    expect(engine.door('buy').first.shape, ShapeKind.circle);
    expect(engine.accents, containsAll(['orange', 'pink', 'purple', 'marigold']));
  });

  test('a poster is stable per product and uses three different accents', () {
    for (final id in ['p_01', 'p_02', '3129d7a45f42', '']) {
      final a = engine.poster(id), b = engine.poster(id);
      expect((a.background, a.circleAccent, a.barY), (b.background, b.circleAccent, b.barY));
      expect({a.background, a.circleAccent, a.barAccent}, hasLength(3));
      expect(a.circleSize, inInclusiveRange(0.44, 0.66));
      expect(a.barRotate, inInclusiveRange(-15, 15));
    }
    final looks = {for (var i = 0; i < 20; i++) engine.poster('p_$i').background};
    expect(looks.length, greaterThan(1), reason: 'different products get different posters');
  });

  test('broken shapes fail at load', () {
    expect(() => ArtEngine(rules((y) => y.replaceFirst('size: 150, right: -40', 'right: -40'))),
        throwsA(isA<ArtRulesError>()));
    expect(() => ArtEngine(rules((y) => y.replaceFirst('size: 150, right: -40', 'size: 150, left: 0, right: -40'))),
        throwsA(isA<ArtRulesError>()));
    expect(() => ArtEngine(rules((y) => y.replaceFirst('rotate: [-15, 15]', 'rotate: [15, -15]'))),
        throwsA(isA<ArtRulesError>()));
    expect(() => rules((y) => y.replaceFirst('shape: circle', 'shape: blob')), throwsA(isA<ConfigError>()));
    expect(() => engine.backdrop('studio'), throwsA(isA<ArtRulesError>()));
  });
}
