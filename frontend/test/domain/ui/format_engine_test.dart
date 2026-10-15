import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/ui/format_engine.dart';
import 'package:craftstream/schemas/ui/format_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/ui/format.yml';
FormatSchema rules([String Function(String)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, FormatSchema.fromJson);
}

void main() {
  final f = FormatEngine(rules());

  test('INR uses Indian grouping and hides zero paise', () {
    expect(f.money(450, 'INR'), '₹450');
    expect(f.money(1000, 'INR'), '₹1,000');
    expect(f.money(120000, 'INR'), '₹1,20,000');
    expect(f.money(12345678, 'INR'), '₹1,23,45,678');
    expect(f.money(499.5, 'INR'), '₹499.50');
    expect(f.money(0.3, 'INR'), '₹0.30');
    expect(f.money(-450, 'INR'), '−₹450');
  });

  test('USD uses western grouping; an unlisted currency shows its code', () {
    expect(f.money(1234.5, 'USD'), r'$1,234.50');
    expect(f.money(1000000, 'USD'), r'$1,000,000');
    expect(f.money(1234, 'EUR'), 'EUR 1,234');
  });

  test('file sizes', () {
    expect(f.bytes(512), '512 B');
    expect(f.bytes(2048), '2 KB');
    expect(f.bytes(8 * 1024 * 1024), '8 MB');
    expect(f.bytes(2150 * 1024 * 1024), '2.1 GB');
  });

  test('video lengths', () {
    expect(f.duration(const Duration(minutes: 12, seconds: 40)), '12:40');
    expect(f.duration(const Duration(seconds: 5)), '0:05');
    expect(f.duration(const Duration(hours: 1, minutes: 2, seconds: 5)), '1:02:05');
  });

  test('activity log date and time', () {
    final at = DateTime(2026, 10, 5, 9, 4, 7);
    expect(f.date(at), '2026-10-05');
    expect(f.time(at), '09:04:07');
  });

  test('bad files are rejected', () {
    expect(
      () => FormatEngine(rules((t) => t.replaceFirst('date: "{yyyy}', 'date: "{YYYY}'))),
      throwsA(isA<FormatRulesError>()),
    );
    expect(
      () => FormatEngine(rules((t) => t.replaceFirst('pattern: "{value} {unit}"', 'pattern: "{value}"'))),
      throwsA(isA<FormatRulesError>()),
    );
    expect(
      () => FormatEngine(rules((t) => t.replaceFirst('grouping: [3, 2]', 'grouping: []'))),
      throwsA(isA<FormatRulesError>()),
    );
    expect(() => rules((t) => '$t\ncurrency_default: INR\n'), throwsA(isA<ConfigError>()));
  });
}
