/// The brick catalogue from bricks.yml, and the checker every screen's bricks go through. Pure Dart.
///
/// A screen YAML node (`{brick: door, role: buy, …}`) becomes a [BrickNode] with defaults filled in, children
/// parsed and actions typed. Anything the catalogue or the rest of the config does not know (an unknown prop,
/// strings key, icon, route …) fails at startup with the screen and position in the message.
library;

import '../../schemas/ui/bricks_schema.dart';

class BricksRulesError implements Exception {
  final String message;
  const BricksRulesError(this.message);
  @override
  String toString() => 'bricks: $message';
}

sealed class ActionSpec {
  const ActionSpec();
}

/// Go to a route; `{path}` parts are filled from the data (`/placed/{item.id}`).
class GoAction extends ActionSpec {
  final String template;
  const GoAction(this.template);
}

class BackAction extends ActionSpec {
  const BackAction();
}

class ToggleThemeAction extends ActionSpec {
  const ToggleThemeAction();
}

/// Ask the screen's data source to do something (`{call: toggle_tag, with: item.value}`). [withPath] is a data
/// path whose value is passed along; bricks that produce a value (a search field) pass their own.
class CallAction extends ActionSpec {
  final String name;
  final String? withPath;
  const CallAction(this.name, [this.withPath]);
}

/// One receipt line: a strings key for the label and a field of the bound record.
class ReceiptRow {
  final String label, field;
  final String? style;
  const ReceiptRow(this.label, this.field, this.style);
}

class BrickNode {
  final String brick;

  /// Every declared prop (defaults filled in): text keys and names as String, `node` as BrickNode, `nodes` as
  /// List<BrickNode>, `action` as ActionSpec, `args` as Map<String, String>, `rows` as List<ReceiptRow>.
  final Map<String, Object?> props;
  final String where;

  /// Data paths: the brick shows only while [when] is truthy and [unless] is not (any brick may have them).
  final String? when, unless;
  const BrickNode(this.brick, this.props, this.where, {this.when, this.unless});

  T? prop<T>(String name) => props[name] as T?;
  T need<T>(String name) => props[name] as T? ?? (throw BricksRulesError('$where: $brick.$name is missing'));
}

/// The names defined elsewhere in the config, so props can be checked when the screens load.
class BrickRefs {
  final bool Function(String key) hasText;
  final bool Function(String template) acceptsRoute;
  final Set<String> icons, roles, tones, colors, styles, spaces, doorArts;
  const BrickRefs({
    required this.hasText,
    required this.acceptsRoute,
    required this.icons,
    required this.roles,
    required this.tones,
    required this.colors,
    required this.styles,
    required this.spaces,
    required this.doorArts,
  });
}

final _path = RegExp(r'^[a-z_][a-z0-9_]*(\.[a-z_][a-z0-9_]*)*$');
final _field = RegExp(r'^[a-z_][a-z0-9_]*$');

class BricksEngine {
  final BricksSchema rules;

  /// Validates the catalogue itself: enums list their options, defaults are valid for their type.
  BricksEngine(this.rules) {
    rules.bricks.forEach((name, b) {
      b.props.forEach((prop, p) {
        final at = '$name.$prop';
        if (p.type == PropType.enumeration && (p.options == null || p.options!.isEmpty)) {
          throw BricksRulesError('$at: an enum needs options');
        }
        if (p.type != PropType.enumeration && p.options != null) throw BricksRulesError('$at: only enums take options');
        final d = p.defaultValue;
        if (d == null) return;
        if (p.required) throw BricksRulesError('$at: a required prop cannot have a default');
        final ok = switch (p.type) {
          PropType.enumeration => p.options!.contains(d),
          PropType.bool => d is bool,
          PropType.number => d is num,
          PropType.node || PropType.nodes || PropType.rows || PropType.action || PropType.args => false,
          _ => d is String,
        };
        if (!ok) throw BricksRulesError('$at: default "$d" does not fit type ${p.type.name}');
      });
    });
  }

  Iterable<String> get names => rules.bricks.keys;

  BrickSchema spec(String name) => rules.bricks[name] ?? (throw BricksRulesError('unknown brick "$name"'));

  Map<String, Object?> style(String name) => spec(name).style;

  /// The strings keys a parsed brick shows (its `text` props and receipt row labels), children not included.
  Iterable<String> textKeysOf(BrickNode n) sync* {
    for (final MapEntry(key: prop, value: p) in spec(n.brick).props.entries) {
      final v = n.props[prop];
      if (p.type == PropType.text && v is String) yield v;
      if (p.type == PropType.rows && v is List<ReceiptRow>) yield* v.map((r) => r.label);
    }
  }

  /// A screen YAML node -> a checked [BrickNode]. [where] names the place for error messages (`home.body[2]`).
  BrickNode parse(Object? raw, String where, BrickRefs refs) {
    if (raw is! Map) throw BricksRulesError('$where: expected a brick, like {brick: text, text: home.title}');
    final name = raw['brick'];
    if (name is! String) throw BricksRulesError('$where: missing "brick:"');
    final at = '$where ($name)';
    final b = rules.bricks[name] ?? (throw BricksRulesError('$where: unknown brick "$name" (see ui/bricks.yml)'));
    String? condition(String key) {
      final v = raw[key];
      if (v == null) return null;
      if (v is! String || !_path.hasMatch(v)) throw BricksRulesError('$at.$key: "$v" is not a data path');
      return v;
    }

    for (final key in raw.keys) {
      if (!const {'brick', 'when', 'unless'}.contains(key) && !b.props.containsKey(key)) {
        throw BricksRulesError('$at: unknown prop "$key" (has: ${b.props.keys.join(', ')})');
      }
    }
    final props = <String, Object?>{};
    b.props.forEach((prop, p) {
      final value = raw[prop] ?? p.defaultValue;
      if (value == null) {
        if (p.required) throw BricksRulesError('$at: "$prop" is required');
        return;
      }
      props[prop] = _value(p, value, '$at.$prop', refs);
    });
    return BrickNode(name, props, at, when: condition('when'), unless: condition('unless'));
  }

  Object? _value(PropSchema p, Object value, String at, BrickRefs refs) {
    String str() => value is String ? value : throw BricksRulesError('$at: expected text, got "$value"');
    String inSet(Set<String> known, String what) {
      final s = str();
      if (!known.contains(s)) throw BricksRulesError('$at: unknown $what "$s"');
      return s;
    }

    switch (p.type) {
      case PropType.text:
        final key = str();
        if (!refs.hasText(key)) throw BricksRulesError('$at: "$key" is not in strings.yml');
        return key;
      case PropType.bind:
        final path = str();
        if (!_path.hasMatch(path)) throw BricksRulesError('$at: "$path" is not a data path like order.total');
        return path;
      case PropType.args:
        if (value is! Map) throw BricksRulesError('$at: expected {placeholder: data.path}');
        return {
          for (final e in value.entries)
            e.key.toString(): _path.hasMatch('${e.value}')
                ? '${e.value}'
                : throw BricksRulesError('$at.${e.key}: "${e.value}" is not a data path'),
        };
      case PropType.action:
        return _action(value, at, refs);
      case PropType.icon:
        return inSet(refs.icons, 'icon');
      case PropType.role:
        return inSet(refs.roles, 'role');
      case PropType.tone:
        return inSet(refs.tones, 'tone');
      case PropType.color:
        return inSet(refs.colors, 'colour');
      case PropType.style:
        return inSet(refs.styles, 'text style');
      case PropType.space:
        return inSet(refs.spaces, 'spacing step');
      case PropType.doorArt:
        return inSet(refs.doorArts, 'door art');
      case PropType.enumeration:
        final s = str();
        if (!p.options!.contains(s)) throw BricksRulesError('$at: "$s" is not one of ${p.options!.join(', ')}');
        return s;
      case PropType.bool:
        return value is bool ? value : throw BricksRulesError('$at: expected true or false');
      case PropType.number:
        return value is num ? value : throw BricksRulesError('$at: expected a number');
      case PropType.node:
        return parse(value, at, refs);
      case PropType.nodes:
        if (value is! List) throw BricksRulesError('$at: expected a list of bricks');
        return [for (final (i, v) in value.indexed) parse(v, '$at[$i]', refs)];
      case PropType.rows:
        if (value is! List) throw BricksRulesError('$at: expected a list of {label, field}');
        return [
          for (final (i, r) in value.indexed)
            if (r is Map && r['label'] is String && r['field'] is String && r.keys.every({'label', 'field', 'style'}.contains))
              ReceiptRow(
                refs.hasText(r['label'] as String) ? r['label'] as String : throw BricksRulesError('$at[$i]: "${r['label']}" is not in strings.yml'),
                _field.hasMatch(r['field'] as String) ? r['field'] as String : throw BricksRulesError('$at[$i]: bad field "${r['field']}"'),
                r['style'] == null || refs.styles.contains(r['style'])
                    ? r['style'] as String?
                    : throw BricksRulesError('$at[$i]: unknown text style "${r['style']}"'),
              )
            else
              throw BricksRulesError('$at[$i]: expected {label: strings.key, field: name, style?: text style}'),
        ];
    }
  }

  ActionSpec _action(Object value, String at, BrickRefs refs) {
    if (value is Map && value.containsKey('call')) {
      final name = value['call'], arg = value['with'];
      if (name is! String || !_field.hasMatch(name)) throw BricksRulesError('$at: call needs a name like load_more');
      if (value.keys.any((k) => k != 'call' && k != 'with')) throw BricksRulesError('$at: a call takes only "with"');
      if (arg != null && (arg is! String || !_path.hasMatch(arg))) {
        throw BricksRulesError('$at: with: "$arg" is not a data path');
      }
      return CallAction(name, arg as String?);
    }
    if (value is! Map || value.length != 1) {
      throw BricksRulesError(
          '$at: an action is one of {go: /path}, {back: true}, {toggle_theme: true}, {call: name, with: path}');
    }
    final MapEntry(:key, value: arg) = value.entries.single;
    switch (key) {
      case 'go':
        if (arg is! String || !arg.startsWith('/')) throw BricksRulesError('$at: go needs a path starting with "/"');
        if (!refs.acceptsRoute(arg)) throw BricksRulesError('$at: "$arg" does not match any route in routes.yml');
        return GoAction(arg);
      case 'back' when arg == true:
        return const BackAction();
      case 'toggle_theme' when arg == true:
        return const ToggleThemeAction();
      default:
        throw BricksRulesError('$at: unknown action "$key"');
    }
  }
}
