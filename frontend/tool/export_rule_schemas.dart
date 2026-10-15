// Writes a JSON Schema for every frontend rule file, so editors validate and autocomplete the YAML while you
// type (the Red Hat YAML extension reads the first-line modeline):
//
//   assets/config/<domain>/<xyz>.yml        -> assets/config/.schemas/<domain>/<xyz>.schema.json
//   assets/config/ui/screens/*.yml (folder) -> assets/config/.schemas/ui/screen.schema.json
//   first line of each YAML:  # yaml-language-server: $schema=<relative path to its schema>
//
// Rule files come from their Dart schema (lib/schemas/<domain>/<xyz>_schema.dart, read with the analyzer:
// fields, required or defaulted, enums, @JsonKey names, snake_case keys, unknown keys rejected, as
// json_serializable does). Screens come from ui/bricks.yml: every brick with its own props, plus icons, tones,
// text styles, spacing steps and roles from the other rule files.
//
//   dart run tool/export_rule_schemas.dart            # write schemas and modelines (make gen runs it)
//   dart run tool/export_rule_schemas.dart --schemas-only
//   test/convention/rule_schemas_test.dart            # fails when a schema or modeline is stale
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:yaml/yaml.dart';

const configDir = 'assets/config';
const schemaDir = '$configDir/.schemas';
const modelinePrefix = '# yaml-language-server: \$schema=';

/// Folders whose files share one schema named after the folder in the singular (D1).
const ruleFolders = {'ui/screens': 'ui/screen'};

void main(List<String> args) {
  final out = buildSchemas();
  Directory(schemaDir).createSync(recursive: true);
  for (final f in Directory(schemaDir).listSync(recursive: true).whereType<File>()) {
    if (!out.containsKey(f.path)) f.deleteSync();
  }
  out.forEach((path, text) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  });
  var lines = 0;
  for (final MapEntry(key: yml, value: schema)
      in args.contains('--schemas-only') ? const <String, String>{}.entries : ruleFiles().entries) {
    if (writeModeline(yml, schema)) lines++;
  }
  stdout.writeln('wrote ${out.length} schemas under $schemaDir; $lines modelines added or fixed');
}

/// Every rule YAML -> the schema file it should point at.
Map<String, String> ruleFiles() {
  final files =
      Directory(configDir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.yml') && !f.path.contains('/.schemas/'))
          .map((f) => f.path)
          .toList()
        ..sort();
  return {
    for (final path in files)
      path: () {
        final rel = path.substring(configDir.length + 1, path.length - 4); // ui/screens/home
        final folder = rel.substring(0, rel.lastIndexOf('/'));
        return '$schemaDir/${ruleFolders[folder] ?? rel}.schema.json';
      }(),
  };
}

/// The modeline a rule file at [yml] needs for [schema].
String modelineFor(String yml, String schema) {
  final from = File(yml).parent.uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final to = schema.split('/');
  var common = 0;
  while (common < from.length && common < to.length - 1 && from[common] == to[common]) {
    common++;
  }
  return '$modelinePrefix${[for (var i = common; i < from.length; i++) '..', ...to.sublist(common)].join('/')}';
}

/// Puts the right modeline on the first line of [yml]; returns whether it changed the file.
bool writeModeline(String yml, String schema) {
  final file = File(yml);
  final lines = file.readAsLinesSync();
  final want = modelineFor(yml, schema);
  if (lines.isNotEmpty && lines.first == want) return false;
  if (lines.isNotEmpty && lines.first.startsWith(modelinePrefix)) lines.removeAt(0);
  file.writeAsStringSync('${[want, ...lines].join('\n')}\n');
  return true;
}

/// Schema file path -> its JSON text, for every rule file and folder.
Map<String, String> buildSchemas() {
  final dart = _DartSchemas.read('lib/schemas');
  final out = <String, String>{};
  for (final schema in ruleFiles().values.toSet()) {
    final rel = schema.substring(schemaDir.length + 1, schema.length - '.schema.json'.length); // logs/activity_log
    final Map<String, Object?> json;
    if (rel == 'ui/screen') {
      json = _screenSchema(dart);
    } else {
      final name = rel.split('/').last;
      final root = '${name.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join()}Schema';
      json = dart.root(root, rel);
    }
    out[schema] = '${const JsonEncoder.withIndent('  ').convert(json)}\n';
  }
  return out;
}

String _snake(String camel) => camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// The json_serializable classes and enums under lib/schemas, as JSON Schema.
class _DartSchemas {
  /// Classes by schema file (`logs/activity_log`), then by name: two files may both have a `PosterSchema`.
  final byFile = <String, Map<String, ClassDeclaration>>{};

  /// The schema file being exported; its own classes win over same-named ones elsewhere.
  String _file = '';

  ClassDeclaration? _class(String name) =>
      byFile[_file]?[name] ?? [for (final m in byFile.values) ?m[name]].firstOrNull;
  final enums = <String, List<String>>{};

  _DartSchemas.read(String dir) {
    for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('_schema.dart')) continue;
      final unit = parseFile(path: f.absolute.path, featureSet: FeatureSet.latestLanguageVersion()).unit;
      for (final d in unit.declarations) {
        if (d is ClassDeclaration && _has(d.metadata, 'JsonSerializable')) {
          final rel = f.path.substring(dir.length + 1, f.path.length - '_schema.dart'.length);
          (byFile[rel] ??= {})[d.namePart.typeName.lexeme] = d;
        }
        if (d is EnumDeclaration) {
          final snake = _args(d.metadata, 'JsonEnum')['fieldRename']?.contains('snake') ?? false;
          enums[d.namePart.typeName.lexeme] = [
            for (final c in d.body.constants) snake ? _snake(c.name.lexeme) : c.name.lexeme,
          ];
        }
      }
    }
  }

  static bool _has(List<Annotation> meta, String name) => meta.any((a) => a.name.name == name);

  static Map<String, String> _args(List<Annotation> meta, String name) => {
    for (final a in meta.where((a) => a.name.name == name))
      for (final e in a.arguments?.arguments ?? const <Expression>[])
        if (e is NamedArgument) e.name.lexeme: e.argumentExpression.toSource(),
  };

  /// Nested classes, shared by `$ref` (recursive ones like RouteSchema need it); filled while building a root.
  Map<String, Object?> _defs = {};

  Map<String, Object?> root(String name, String rel) {
    _defs = {};
    _file = rel;
    final body = _object(name, const {});
    return {
      r'$schema': 'http://json-schema.org/draft-07/schema#',
      'title': 'assets/config/$rel.yml',
      ...body,
      if (_defs.isNotEmpty)
        'definitions': Map.fromEntries(_defs.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
    };
  }

  /// A nested class by reference; [args] are its type arguments as Dart source (ModesSchema<ShadowSetSchema>).
  Map<String, Object?> _ref(String name, List<String> args) {
    final key = args.isEmpty ? name : '${name}_${args.join('_').replaceAll(RegExp(r'[^A-Za-z0-9_]'), '')}';
    if (!_defs.containsKey(key)) {
      _defs[key] = null; // in progress: a recursive use only refers to it
      final params = _class(name)?.namePart.typeParameters?.typeParameters ?? const <TypeParameter>[];
      _defs[key] = _object(name, {for (final (i, p) in params.indexed) p.name.lexeme: args[i]});
    }
    return {r'$ref': '#/definitions/$key'};
  }

  /// A class as an object schema; [bind] fills its type parameters (ModesSchema<T>).
  Map<String, Object?> _object(String name, Map<String, String> bind) {
    final c = _class(name) ?? (throw StateError('no @JsonSerializable class $name in lib/schemas'));
    final props = <String, Object?>{};
    final required = <String>[];
    final ctor = c.body.members.whereType<ConstructorDeclaration>().firstWhere((k) => k.name == null);
    final optional = <String>{};
    final defaults = <String, String>{};
    for (final p in ctor.parameters.parameters) {
      final name = p.name?.lexeme;
      if (name == null) continue;
      if (!p.isRequired) optional.add(name);
      final dflt = p.defaultClause;
      if (dflt != null) defaults[name] = dflt.value.toSource();
    }
    for (final field in c.body.members.whereType<FieldDeclaration>()) {
      if (field.isStatic) continue;
      final type = field.fields.type?.toSource() ?? 'Object?';
      final rename = _args(field.metadata, 'JsonKey')['name'];
      for (final v in field.fields.variables) {
        final dartName = v.name.lexeme;
        final key = rename != null ? rename.replaceAll("'", '') : _snake(dartName);
        final custom = _args(field.metadata, 'JsonKey').containsKey('fromJson');
        final s = custom ? <String, Object?>{} : {..._type(type, bind)};
        final dflt = _jsonDefault(defaults[dartName]);
        if (dflt != null) s['default'] = dflt;
        props[key] = s;
        if (!optional.contains(dartName) && !type.endsWith('?')) required.add(key);
      }
    }
    return {
      'type': 'object',
      'additionalProperties': false,
      'properties': props,
      if (required.isNotEmpty) 'required': required,
    };
  }

  Object? _jsonDefault(String? src) => switch (src) {
    null => null,
    'true' => true,
    'false' => false,
    final s when num.tryParse(s) != null => num.parse(s),
    final s when s.startsWith("'") => s.substring(1, s.length - 1),
    _ => null, // const [], enum values …: leave to the description
  };

  Map<String, Object?> _type(String type, Map<String, String> bind) {
    var t = type.trim();
    if (t.endsWith('?')) t = t.substring(0, t.length - 1);
    if (bind.containsKey(t)) return _type(bind[t]!, const {});
    final generic = RegExp(r'^(\w+)<(.+)>$').firstMatch(t);
    if (generic != null) {
      final outer = generic[1]!, inner = _splitArgs(generic[2]!);
      return switch (outer) {
        'List' => {'type': 'array', 'items': _type(inner.single, bind)},
        'Map' => {'type': 'object', 'additionalProperties': _type(inner.last, bind)},
        _ => _ref(outer, [for (final a in inner) bind[a] ?? a]),
      };
    }
    return switch (t) {
      'String' => {'type': 'string'},
      'int' => {'type': 'integer'},
      'double' || 'num' => {'type': 'number'},
      'bool' => {'type': 'boolean'},
      'Object' || 'dynamic' => <String, Object?>{},
      _ when enums.containsKey(t) => {'enum': enums[t]},
      _ => _ref(t, const []),
    };
  }

  static List<String> _splitArgs(String s) {
    final out = <String>[];
    var depth = 0, start = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '<') depth++;
      if (s[i] == '>') depth--;
      if (s[i] == ',' && depth == 0) {
        out.add(s.substring(start, i).trim());
        start = i + 1;
      }
    }
    return out..add(s.substring(start).trim());
  }
}

YamlMap _yaml(String rel) => loadYaml(File('$configDir/$rel').readAsStringSync()) as YamlMap;

/// One screen: its own keys (from ScreenSchema) with every brick list typed from ui/bricks.yml.
Map<String, Object?> _screenSchema(_DartSchemas dart) {
  final screen = dart.root('ScreenSchema', 'ui/screens/<name>');
  final bricks = _yaml('ui/bricks.yml')['bricks'] as YamlMap;
  final theme = _yaml('ui/theme.yml');
  final names = {
    'icon': [...(_yaml('ui/icons.yml')['icons'] as YamlMap).keys.map((k) => '$k')],
    'tone': [...(theme['tones'] as YamlMap).keys.map((k) => '$k')],
    'style': [...(theme['styles'] as YamlMap).keys.map((k) => '$k')],
    'space': [...(theme['spacing'] as YamlMap).keys.map((k) => '$k')],
    'role': [...(_yaml('app/navigation.yml')['roles'] as YamlMap).keys.map((k) => '$k')],
    'size_class': [for (final c in _yaml('ui/layout.yml')['size_classes'] as YamlList) '${(c as YamlMap)['name']}'],
  };

  Map<String, Object?> prop(YamlMap p) {
    final type = '${p['type']}';
    final s = <String, Object?>{
      ...switch (type) {
        'icon' || 'tone' || 'style' || 'space' || 'role' => {'enum': names[type]},
        'enum' => {
          'enum': [...(p['options'] as YamlList).map((o) => '$o')],
        },
        'bool' => {'type': 'boolean'},
        'number' => {'type': 'number'},
        'args' => {
          'type': 'object',
          'additionalProperties': {'type': 'string'},
        },
        'action' => {r'$ref': '#/definitions/action'},
        'node' => {r'$ref': '#/definitions/node'},
        'nodes' => {
          'type': 'array',
          'items': {r'$ref': '#/definitions/node'},
        },
        'rows' || 'steps' => {
          'type': 'array',
          'items': {'type': 'object'},
        },
        _ => {'type': 'string'}, // text keys, bindings, colours, door art
      },
      'description': type,
    };
    if (p['default'] != null) s['default'] = p['default'] is YamlNode ? '${p['default']}' : p['default'];
    return s;
  }

  final common = {
    'brick': {
      'enum': [...bricks.keys.map((k) => '$k')],
    },
    'when': {'type': 'string', 'description': 'shown only when this binding is truthy'},
    'unless': {'type': 'string', 'description': 'hidden when this binding is truthy'},
    'only': {
      'type': 'array',
      'items': {'enum': names['size_class']},
      'description': 'shown only at these size classes',
    },
  };
  final node = {
    'type': 'object',
    'required': ['brick'],
    'properties': common,
    'allOf': [
      for (final MapEntry(key: name, value: b) in bricks.entries)
        {
          'if': {
            'properties': {
              'brick': {'const': '$name'},
            },
          },
          'then': {
            'description': '${(b as YamlMap)['about'] ?? ''}'.trim(),
            'additionalProperties': false,
            'properties': {
              ...common,
              for (final MapEntry(key: k, value: p) in ((b['props'] as YamlMap?) ?? YamlMap()).entries)
                '$k': prop(p as YamlMap),
            },
            'required': [
              for (final MapEntry(key: k, value: p) in ((b['props'] as YamlMap?) ?? YamlMap()).entries)
                if ((p as YamlMap)['required'] == true) '$k',
            ],
          },
        },
    ],
  };
  final action = {
    'type': 'object',
    'description': '{go: /path}, {back: true}, {toggle_theme: true} or {call: name, with: value, then: action}',
    'additionalProperties': false,
    'properties': {
      'go': {'type': 'string'},
      'back': {'const': true},
      'toggle_theme': {'const': true},
      'call': {'type': 'string'},
      'with': {},
      'then': {r'$ref': '#/definitions/action'},
    },
  };
  final props = Map<String, Object?>.from(screen['properties'] as Map);
  for (final list in ['top', 'body', 'bottom', 'empty', 'error']) {
    props[list] = {
      'type': 'array',
      'items': {r'$ref': '#/definitions/node'},
    };
  }
  return {
    ...screen,
    'properties': props,
    'definitions': {'node': node, 'action': action},
  };
}
