import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/orders/orders_engine.dart';
import 'package:craftstream/schemas/orders/orders_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/orders/orders.yml';
OrdersSchema rules([String Function(String yaml)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, OrdersSchema.fromJson);
}

void main() {
  final engine = OrdersEngine(rules());

  test('orders.yml loads', () {
    expect(engine.storageKey, isNotEmpty);
    expect(engine.refreshOnStart, isTrue);
  });

  test('newest first, no repeats, at most `keep`', () {
    final small = OrdersEngine(rules((y) => y.replaceFirst('keep: 50', 'keep: 2')));
    expect(small.trim(['c', 'b', 'c', 'a'], (s) => s), ['c', 'b']);
  });

  test('bad rules fail at load', () {
    expect(() => OrdersEngine(rules((y) => y.replaceFirst('keep: 50', 'keep: 0'))), throwsA(isA<OrdersRulesError>()));
    expect(() => rules((y) => y.replaceFirst('keep: 50', 'kept: 50')), throwsA(isA<ConfigError>()));
  });
}
