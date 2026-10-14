/// The Buy and Sell roles from navigation.yml. Pure Dart.
library;

import '../../schemas/app/navigation_schema.dart';

class NavigationRulesError implements Exception {
  final String message;
  const NavigationRulesError(this.message);
  @override
  String toString() => 'navigation.yml: $message';
}

class NavigationEngine {
  final NavigationSchema rules;

  /// Validates: at least one role, numbers unique, paths absolute and claimed by one role only.
  NavigationEngine(this.rules) {
    if (rules.roles.isEmpty) throw const NavigationRulesError('roles is empty');
    final numbers = <String>{}, claimed = <String>{};
    rules.roles.forEach((name, r) {
      if (!numbers.add(r.number)) throw NavigationRulesError('$name: number "${r.number}" is used twice');
      for (final p in [r.home, ...r.paths]) {
        if (!p.startsWith('/')) throw NavigationRulesError('$name: "$p" must start with "/"');
      }
      for (final p in r.paths) {
        if (!claimed.add(p)) throw NavigationRulesError('$name: "$p" belongs to two roles');
      }
    });
  }

  Iterable<String> get names => rules.roles.keys;

  RoleSchema role(String name) => rules.roles[name] ?? (throw NavigationRulesError('unknown role "$name"'));

  /// The role a location belongs to (longest matching path wins), or null.
  String? roleOf(String location) {
    String? best;
    var bestLength = -1;
    rules.roles.forEach((name, r) {
      for (final p in r.paths) {
        final hit = location == p || location.startsWith('$p/') || location.startsWith('$p?');
        if (hit && p.length > bestLength) {
          best = name;
          bestLength = p.length;
        }
      }
    });
    return best;
  }
}
