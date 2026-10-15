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
    expect(engine.defaultSort, 'newest');
    expect(engine.sortIds, ['newest', 'price_low', 'price_high']);
    expect(engine.sortFields, {'price'});
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
    Object? price(int p, String field) => field == 'price' ? p : null;
    expect(engine.sort(prices, 'newest', price), [300, 100, 200]);
    expect(engine.sort(prices, 'price_low', price), [100, 200, 300]);
    expect(engine.sort(prices, 'price_high', price), [300, 200, 100]);
    expect(() => engine.sort(prices, 'rating', price), throwsA(isA<FiltersRulesError>()));
  });

  test('a new sort is only YAML: any field, either direction; ties keep the API order', () {
    final byTitle = FiltersEngine(
      rules(
        (t) =>
            '$t  - id: title_az\n    label: discover.sort_newest\n'
            '    field: title\n    direction: asc\n',
      ),
    );
    final items = [
      {'title': 'mug', 'n': 1},
      {'title': 'bowl', 'n': 2},
      {'title': 'mug', 'n': 3},
    ];
    expect(byTitle.sort(items, 'title_az', (m, f) => m[f]).map((m) => m['n']), [2, 1, 3]);
    expect(byTitle.sortNamed('title_az'), 'title_az');
  });

  test('re-tapping the selected tag clears it', () {
    expect(engine.nextTag(null, 'pottery'), 'pottery');
    expect(engine.nextTag('brass', 'pottery'), 'pottery');
    expect(engine.nextTag('pottery', 'pottery'), isNull);
    final sticky = FiltersEngine(rules((t) => t.replaceFirst('tag_retap_clears: true', 'tag_retap_clears: false')));
    expect(sticky.nextTag('pottery', 'pottery'), 'pottery');
  });

  test('bad files are rejected', () {
    expect(
      () => FiltersEngine(rules((t) => t.replaceFirst('default: true', 'default: false'))),
      throwsA(isA<FiltersRulesError>()),
    );
    expect(
      () => FiltersEngine(rules((t) => t.replaceFirst('page_size: 24', 'page_size: 0'))),
      throwsA(isA<FiltersRulesError>()),
    );
    expect(
      () => FiltersEngine(rules((t) => t.replaceFirst('    direction: asc\n', ''))),
      throwsA(isA<FiltersRulesError>()),
    );
    expect(() => rules((t) => t.replaceFirst('direction: asc', 'direction: up')), throwsA(isA<ConfigError>()));
    expect(() => rules((t) => '$t\nsort_by: newest\n'), throwsA(isA<ConfigError>()));
  });
}
