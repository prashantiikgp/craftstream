import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/ui/status_engine.dart';
import 'package:craftstream/schemas/ui/status_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const path = 'assets/config/ui/status.yml';
StatusSchema rules([String Function(String yaml)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, StatusSchema.fromJson);
}

/// The enum values of a field in models/<model>.yml, the single definition of what the API sends.
Set<String> modelEnum(String model, String field) {
  final doc = loadYaml(File('../models/$model.yml').readAsStringSync()) as YamlMap;
  final f = (doc['fields'] as YamlMap)[field] as YamlMap;
  return {for (final v in f['values'] as YamlList) v.toString()};
}

void main() {
  final engine = StatusEngine(rules());

  test('status.yml covers exactly the statuses the API sends', () {
    expect(engine.values('video').toSet(), modelEnum('product', 'video_status'));
    expect(engine.values('order').toSet(), modelEnum('order', 'status'));
  });

  test('each status has a look', () {
    expect(engine.look('video', 'processing').progress, isTrue);
    expect(engine.look('video', 'failed').retry, isTrue);
    expect(engine.look('order', 'placed').tone, 'success');
    expect(engine.stringKeys, contains('status.placed'));
  });

  test('unknown statuses and kinds fail loudly', () {
    expect(() => engine.look('video', 'archived'), throwsA(isA<StatusRulesError>()));
    expect(() => engine.look('payment', 'paid'), throwsA(isA<StatusRulesError>()));
    expect(() => rules((y) => y.replaceFirst('progress: true', 'progres: true')), throwsA(isA<ConfigError>()));
  });
}
