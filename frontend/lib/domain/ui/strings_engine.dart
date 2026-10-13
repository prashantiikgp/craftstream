/// Every user-visible string, from strings.yml. Screens call `context.s('group.key', {'name': value})`.
/// Unknown keys and missing placeholder values throw, so a typo fails in tests instead of showing "null".
library;

import '../../schemas/ui/strings_schema.dart';

class StringsError implements Exception {
  final String message;
  const StringsError(this.message);
  @override
  String toString() => 'strings.yml: $message';
}

final _placeholder = RegExp(r'\{([a-z_][a-z0-9_]*)\}');
final _key = RegExp(r'^[a-z][a-z0-9_]*$');

class StringsEngine {
  final StringsSchema rules;
  final Map<String, String> _flat;

  /// Validates: group and key names are snake_case, no text is empty, braces only wrap placeholder names.
  StringsEngine(this.rules) : _flat = {} {
    rules.strings.forEach((group, entries) {
      if (!_key.hasMatch(group)) throw StringsError('group "$group" must be snake_case');
      entries.forEach((key, text) {
        if (!_key.hasMatch(key)) throw StringsError('key "$group.$key" must be snake_case');
        if (text.trim().isEmpty) throw StringsError('"$group.$key" is empty');
        final stray = text.replaceAll(_placeholder, '');
        if (stray.contains('{') || stray.contains('}')) {
          throw StringsError('"$group.$key" has a malformed {placeholder}');
        }
        _flat['$group.$key'] = text;
      });
    });
  }

  String get locale => rules.locale;

  Iterable<String> get keys => _flat.keys;

  bool has(String key) => _flat.containsKey(key);

  /// Placeholder names a string expects, e.g. {artisan} -> ['artisan'].
  Set<String> placeholdersOf(String key) => {for (final m in _placeholder.allMatches(_raw(key))) m.group(1)!};

  /// The text for [key] with `{name}` replaced from [args]. Throws on an unknown key or a missing value.
  String get(String key, [Map<String, Object> args = const {}]) {
    return _raw(key).replaceAllMapped(_placeholder, (m) {
      final name = m.group(1)!;
      final value = args[name];
      if (value == null) throw StringsError('"$key" needs a value for {$name}');
      return value.toString();
    });
  }

  String _raw(String key) => _flat[key] ?? (throw StringsError('unknown key "$key"'));
}
