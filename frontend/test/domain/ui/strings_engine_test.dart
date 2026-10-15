import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/ui/strings_engine.dart';
import 'package:craftstream/schemas/ui/strings_schema.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/harness.dart';

const path = 'assets/config/ui/strings.yml';
StringsSchema rules([String Function(String)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, StringsSchema.fromJson);
}

void main() {
  final engine = StringsEngine(rules());

  test('strings.yml loads', () {
    expect(engine.locale, 'en');
    expect(engine.get('placed.title'), 'Order placed');
  });

  test('placeholders are filled and checked', () {
    expect(engine.get('product.by_artisan', {'artisan': 'Meera Devi'}), 'by Meera Devi');
    expect(engine.placeholdersOf('upload.progress_bytes'), {'sent', 'total', 'percent'});
    expect(() => engine.get('product.by_artisan'), throwsA(isA<StringsError>()));
  });

  test('unknown keys throw instead of showing nothing', () {
    expect(() => engine.get('product.nope'), throwsA(isA<StringsError>()));
  });

  test('bad files are rejected', () {
    expect(() => StringsEngine(rules((t) => t.replaceFirst('back: Back', 'Back: Back'))), throwsA(isA<StringsError>()));
    expect(() => StringsEngine(rules((t) => t.replaceFirst('by {artisan}', 'by {artisan'))),
        throwsA(isA<StringsError>()));
    expect(() => rules((t) => t.replaceFirst('locale: en', 'locale: en\nlocales: [en]')), throwsA(isA<ConfigError>()));
  });

  // Every 'group.key' literal in lib/ must exist, and every key in strings.yml must be used: by lib/, or by the rule
  // YAML (screen bricks' text props, navigation labels, status labels), read through the loaded engines.
  test('strings.yml, lib/ and the rule YAML agree', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final config = await testConfig();
    final groups = {for (final k in engine.keys) k.split('.').first};
    final literal = RegExp(r"'([a-z][a-z0-9_]*)\.([a-z][a-z0-9_]*)'");
    final used = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      for (final m in literal.allMatches(f.readAsStringSync())) {
        if (groups.contains(m.group(1))) used.add('${m.group(1)}.${m.group(2)}');
      }
    }
    expect(used.where((k) => !engine.has(k)), isEmpty, reason: 'keys used in lib/ but missing from strings.yml');
    for (final name in config.screens.names) {
      for (final brick in config.screens.screen(name).allBricks) {
        used.addAll(config.bricks.textKeysOf(brick));
      }
    }
    used.addAll([for (final r in config.navigation.names) config.navigation.role(r).label]);
    used.addAll(config.status.stringKeys);
    used.addAll(config.filters.sortLabels);
    used.addAll(config.activityLog.stringKeys);
    expect(engine.keys.where((k) => !used.contains(k)), isEmpty, reason: 'keys in strings.yml that nothing uses');
  });
}
