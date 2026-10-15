import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/dev/mock_engine.dart';
import 'package:craftstream/schemas/dev/mock_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/dev/mock.yml';
MockSchema rules([String Function(String)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, MockSchema.fromJson);
}

void main() {
  final engine = MockEngine(rules());

  test('timing: small delays so loading states show', () {
    expect(engine.latency, const Duration(milliseconds: 450));
    expect(engine.chunkDelay, const Duration(milliseconds: 140));
    expect(engine.processingTime, const Duration(seconds: 8));
  });

  test('fixtures: 14 listings, three of them this artisan\'s (live, processing, failed)', () {
    expect(engine.products, hasLength(14));
    expect(engine.myProductIds, ['p_01', 'p_13', 'p_14']);
    expect(engine.artisanName, 'Meera Devi');
    expect(
      [for (final id in engine.myProductIds) engine.products.firstWhere((p) => p.id == id).status],
      ['ready', 'processing', 'failed'],
    );
    // Newest first, nine hours apart, from 1 Oct 2026 01:00 local time.
    expect(engine.createdAt(engine.products.first), DateTime(2026, 10, 1, 1));
    expect(engine.createdAt(engine.products[1]), DateTime(2026, 9, 30, 16));
  });

  test('mock:// addresses and API stand-ins', () {
    expect(engine.hlsUrlFor('p_03'), 'mock://media/p_03/master.m3u8');
    expect(engine.uploadUrlFor('p_new1'), 'mock://uploads/p_new1');
    expect(engine.event('order_placed')!.group, 'order');
    expect(engine.event('no_such_event'), isNull);
    expect(engine.uploadPolicy.chunkSizeBytes, 8 * 1024 * 1024);
    expect(engine.productPageSize, 24);
    expect(engine.logPageSize, 30);
  });

  test('sample videos: one fits the 15:00 limit, one does not', () {
    final lengths = engine.videos.map(engine.videoLength).toList();
    expect(lengths.where((d) => d.inSeconds <= engine.uploadPolicy.maxDurationSeconds), hasLength(1));
    expect(lengths.where((d) => d.inSeconds > engine.uploadPolicy.maxDurationSeconds), hasLength(1));
  });

  test('bad files are rejected', () {
    expect(() => MockEngine(rules((t) => t.replaceFirst('- id: p_02', '- id: p_01'))), throwsA(isA<MockRulesError>()));
    expect(
      () => MockEngine(rules((t) => t.replaceFirst('created_at: "2026-10-01T01:00:00"', 'created_at: "yesterday"'))),
      throwsA(isA<MockRulesError>()),
    );
    expect(
      () => MockEngine(rules((t) => t.replaceFirst('"mock://uploads/{id}"', '"mock://uploads/x"'))),
      throwsA(isA<MockRulesError>()),
    );
    expect(() => rules((t) => '$t\nnetwork: slow\n'), throwsA(isA<ConfigError>()));
  });
}
