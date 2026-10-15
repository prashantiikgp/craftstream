/// Shared helper behind every `<xyz>_loader`: read a YAML rule file from assets/config/ and
/// validate it with its schema's `fromJson` (which rejects unknown keys).
library;

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'config_bundle.dart';

class ConfigError implements Exception {
  final String file;
  final String problem;
  const ConfigError(this.file, this.problem);
  @override
  String toString() => 'Config error in $file: $problem';
}

/// Converts YamlMap / YamlList into plain Dart maps and lists, the shape `fromJson` expects.
Object? plainYaml(Object? node) => switch (node) {
      YamlMap m => {for (final e in m.entries) e.key.toString(): plainYaml(e.value)},
      YamlList l => [for (final v in l) plainYaml(v)],
      _ => node,
    };

/// Parses YAML text and validates it; [file] is only used in error messages.
T parseYaml<T>(String text, String file, T Function(Map<String, dynamic>) fromJson) {
  final Object? data;
  try {
    data = plainYaml(loadYaml(text));
  } on YamlException catch (e) {
    throw ConfigError(file, 'not valid YAML: ${e.message}');
  }
  if (data is! Map<String, dynamic>) throw ConfigError(file, 'top level must be a mapping');
  try {
    return fromJson(data);
  } catch (e) {
    throw ConfigError(file, e.toString());
  }
}

/// Loads `assets/config/<relativePath>` and validates it.
Future<T> loadYamlAsset<T>(String relativePath, T Function(Map<String, dynamic>) fromJson,
    {AssetBundle? bundle}) async {
  final path = 'assets/config/$relativePath';
  final text = await (bundle ?? rootBundle).loadString(path);
  return parseYaml(text, path, fromJson);
}

/// Loads every `*.yml` in the rule folder `assets/config/<relativeDir>/`, keyed by file name without `.yml`
/// (`ui/screens/home.yml` -> `home`). Each file is validated on its own, so errors name the file.
Future<Map<String, T>> loadYamlFolder<T>(String relativeDir, T Function(Map<String, dynamic>) fromJson,
    {AssetBundle? bundle}) async {
  final b = bundle ?? rootBundle;
  final prefix = 'assets/config/$relativeDir/';
  // The web config bundle already lists its files; otherwise ask the asset manifest.
  final listed = b is ConfigBundle ? b.keysUnder(prefix) : (await AssetManifest.loadFromAssetBundle(b)).listAssets();
  final paths = listed.where((p) => p.startsWith(prefix) && p.endsWith('.yml')).toList()..sort();
  if (paths.isEmpty) throw ConfigError(prefix, 'no .yml files (is the folder listed in pubspec.yaml?)');
  return {
    for (final path in paths)
      path.substring(prefix.length, path.length - 4): parseYaml(await b.loadString(path), path, fromJson),
  };
}
