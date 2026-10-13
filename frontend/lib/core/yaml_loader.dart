/// Shared helper behind every `<xyz>_loader`: read a YAML rule file from assets/config/ and
/// validate it with its schema's `fromJson` (which rejects unknown keys).
library;

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

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
