import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/ui/layout_engine.dart';
import 'package:craftstream/schemas/ui/layout_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/ui/layout.yml';
LayoutSchema rules([String Function(String)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, LayoutSchema.fromJson);
}

void main() {
  final engine = LayoutEngine(rules());

  test('devices map to the expected size classes', () {
    expect(engine.sizeClassFor(360).name, 'compact');     // phone
    expect(engine.sizeClassFor(800).name, 'medium');      // tablet portrait
    expect(engine.sizeClassFor(1100).name, 'expanded');   // tablet landscape
    expect(engine.sizeClassFor(1440).name, 'large');      // desktop Chrome
  });

  test('navigation and product layout follow the class', () {
    expect(engine.usesRail(360), isFalse);
    expect(engine.usesRail(1100), isTrue);
    expect(engine.productSideBySide(800), isFalse);
    expect(engine.productSideBySide(1100), isTrue);
  });

  test('grid drops columns rather than squeezing cards below min_width', () {
    expect(engine.gridColumns(360), 2);
    expect(engine.gridColumns(320), 1);   // 2 cards would be narrower than 150
    expect(engine.gridColumns(1440), 5);
  });

  test('content width is capped on big screens', () {
    expect(engine.contentWidth(2560), 1180 - 2 * 32);
  });

  test('bad layout rules fail at load', () {
    expect(() => LayoutEngine(rules((y) => y.replaceFirst('min_width: 600', 'min_width: 1300'))),
        throwsA(isA<LayoutRulesError>()));
    expect(() => rules((y) => y.replaceFirst('navigation: rail', 'navigation: drawer')), throwsA(isA<ConfigError>()));
  });
}
