// Editors validate the rule YAML as you type: every file starts with a modeline pointing at its JSON Schema, and
// the schemas match lib/schemas and ui/bricks.yml. Regenerate both with `make gen` (tool/export_rule_schemas.dart).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/export_rule_schemas.dart';

void main() {
  test('the JSON Schemas are up to date', () {
    final want = buildSchemas();
    final have = {
      for (final f in Directory(schemaDir).listSync(recursive: true).whereType<File>()) f.path: f.readAsStringSync(),
    };
    expect(have.keys.toSet(), want.keys.toSet(), reason: 'run make gen');
    for (final MapEntry(:key, :value) in want.entries) {
      expect(have[key], value, reason: '$key is stale: run make gen');
    }
  });

  test('every rule file starts with its schema modeline', () {
    final missing = [
      for (final MapEntry(key: yml, value: schema) in ruleFiles().entries)
        if (File(yml).readAsLinesSync().first != modelineFor(yml, schema)) yml,
    ];
    expect(missing, isEmpty, reason: 'run make gen');
  });
}
