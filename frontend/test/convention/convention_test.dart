// The architecture rule, checked: every YAML under assets/config/ has a schema, a loader, an engine and an engine
// test named after it, and nothing in lib/schemas or lib/domain is left without its YAML.
//
//   assets/config/<domain>/<xyz>.yml          -> <xyz>_schema / _loader / _engine / _engine_test
//   assets/config/<domain>/<folder>/*.yml     -> one trio named after the folder in the singular
//                                                (ui/screens/*.yml -> ui/screen_schema.dart ...)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

class RuleSet {
  final String domain, name, source; // source: the YAML file or folder it comes from
  const RuleSet(this.domain, this.name, this.source);
  String get schema => 'lib/schemas/$domain/${name}_schema.dart';
  String get loader => 'lib/domain/$domain/${name}_loader.dart';
  String get engine => 'lib/domain/$domain/${name}_engine.dart';
  String get test => 'test/domain/$domain/${name}_engine_test.dart';
}

String singular(String folder) => folder.endsWith('s') ? folder.substring(0, folder.length - 1) : folder;

List<RuleSet> ruleSets() {
  final sets = <RuleSet>[];
  for (final domain in Directory('assets/config').listSync().whereType<Directory>()) {
    final d = domain.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (d.startsWith('.')) continue; // .schemas/: generated JSON Schemas for the editor, not rules
    for (final e in domain.listSync()) {
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (e is File && name.endsWith('.yml')) {
        sets.add(RuleSet(d, name.substring(0, name.length - 4), e.path));
      } else if (e is Directory) {
        sets.add(RuleSet(d, singular(name), e.path));
      }
    }
  }
  return sets;
}

void main() {
  final sets = ruleSets();

  test('there are rule files to check', () => expect(sets, isNotEmpty));

  test('every rule file has its schema, loader, engine and engine test', () {
    final missing = [
      for (final s in sets)
        for (final f in [s.schema, s.loader, s.engine, s.test])
          if (!File(f).existsSync()) '${s.source} needs $f',
    ];
    expect(missing, isEmpty);
  });

  test('every loader reads its YAML through core/yaml_loader', () {
    final bad = [
      for (final s in sets)
        if (File(s.loader).existsSync() && !File(s.loader).readAsStringSync().contains('loadYaml'))
          '${s.loader} must call loadYamlAsset / loadYamlFolder',
    ];
    expect(bad, isEmpty);
  });

  test('every rule folder in assets/config is listed in pubspec.yaml', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final listed = {for (final a in (pubspec['flutter'] as YamlMap)['assets'] as YamlList) a.toString()};
    final dirs = {
      for (final f in Directory('assets/config').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.yml')) '${f.parent.path}/',
    };
    expect(dirs.difference(listed), isEmpty, reason: 'add these folders to flutter.assets in pubspec.yaml');
  });

  test('no schema, loader or engine is left without its YAML', () {
    final known = {for (final s in sets) '${s.domain}/${s.name}'};
    final orphans = <String>[];
    for (final (root, suffixes) in [
      ('lib/schemas', ['_schema.dart']),
      ('lib/domain', ['_loader.dart', '_engine.dart']),
    ]) {
      for (final f in Directory(root).listSync(recursive: true).whereType<File>()) {
        final rel = f.path.substring(root.length + 1);
        for (final suffix in suffixes) {
          if (rel.endsWith(suffix) && !known.contains(rel.substring(0, rel.length - suffix.length))) {
            orphans.add(f.path);
          }
        }
      }
    }
    expect(orphans, isEmpty, reason: 'each of these needs a YAML file in assets/config/');
  });
}
