import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/catalog/filters_engine.dart';
import 'package:craftstream/schemas/catalog/filters_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/catalog/filters.yml';
FiltersSchema rules([String Function(String)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, FiltersSchema.fromJson);
}

void main() {
  final engine = FiltersEngine(rules());

  test('filters.yml loads', () {
    expect(engine.debounce, const Duration(milliseconds: 350));
    expect(engine.pageSize, 24);
    expect(engine.defaultSort, SortId.newest);
    expect(engine.sortIds, [SortId.newest, SortId.priceLow, SortId.priceHigh]);
  });

  test('queries are tidied, short ones ignored, long ones cut', () {
    expect(engine.normaliseQuery('  clay   mug '), 'clay mug');
    expect(engine.normaliseQuery('a'), isNull);
    expect(engine.normaliseQuery('x' * 200)!.length, 80);
  });

  test('chips: featured tags that exist first, then the most used, capped', () {
    expect(engine.chipTags(['kitchen', 'brass', 'pottery', 'home']), ['pottery', 'brass', 'kitchen', 'home']);
    expect(engine.chipTags([for (var i = 0; i < 30; i++) 't$i']).length, 10);
    expect(engine.chipTags([]), isEmpty);
  });

  test('sorting happens on the device; newest keeps API order', () {
    final prices = [300, 100, 200];
    expect(engine.sort(prices, SortId.newest, (p) => p), [300, 100, 200]);
    expect(engine.sort(prices, SortId.priceLow, (p) => p), [100, 200, 300]);
    expect(engine.sort(prices, SortId.priceHigh, (p) => p), [300, 200, 100]);
  });

  test('bad files are rejected', () {
    expect(() => FiltersEngine(rules((t) => t.replaceFirst('default: true', 'default: false'))),
        throwsA(isA<FiltersRulesError>()));
    expect(() => FiltersEngine(rules((t) => t.replaceFirst('page_size: 24', 'page_size: 0'))),
        throwsA(isA<FiltersRulesError>()));
    expect(() => rules((t) => t.replaceFirst('- id: price_low', '- id: rating')), throwsA(isA<ConfigError>()));
    expect(() => rules((t) => '$t\nsort_by: newest\n'), throwsA(isA<ConfigError>()));
  });
}
