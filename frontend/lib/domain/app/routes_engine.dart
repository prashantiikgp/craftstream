/// Routes from routes.yml, flattened to full paths and checked. Pure Dart: core/router.dart turns them into a
/// GoRouter; screens and tests ask whether a `go:` target leads anywhere.
library;

import '../../schemas/app/routes_schema.dart';

class RoutesRulesError implements Exception {
  final String message;
  const RoutesRulesError(this.message);
  @override
  String toString() => 'routes.yml: $message';
}

/// One route with its full path (`/product/:id/buy`), the full path it is nested under ('' at the top level) and
/// what it shows.
class RouteEntry {
  final String path, parent;
  final String? screen, legacy;
  final bool shell, devOnly;
  final List<String> params;
  const RouteEntry(this.path,
      {this.parent = '', this.screen, this.legacy, this.shell = false, this.devOnly = false, this.params = const []});

  /// [path] relative to [parent], as GoRouter wants nested routes.
  String get relativePath => parent.isEmpty ? path : path.substring(parent.length + 1);
}

final _segment = RegExp(r'^(:[a-z][a-z0-9_]*|[a-z0-9][a-z0-9_-]*)$');

class RoutesEngine {
  final RoutesSchema rules;
  final List<RouteEntry> entries = [];

  /// Validates: each route shows exactly one thing, paths are well formed and unique, the initial route exists.
  RoutesEngine(this.rules) {
    void walk(List<RouteSchema> routes, String parent) {
      for (final r in routes) {
        final top = parent.isEmpty;
        if (top != r.path.startsWith('/')) {
          throw RoutesRulesError('"${r.path}": top-level paths start with "/", nested paths do not');
        }
        final full = top ? r.path : '$parent/${r.path}';
        if ((r.screen == null) == (r.legacy == null)) {
          throw RoutesRulesError('"$full" needs exactly one of screen or legacy');
        }
        final segments = full.split('/').where((s) => s.isNotEmpty).toList();
        for (final s in segments) {
          if (!_segment.hasMatch(s)) throw RoutesRulesError('"$full": "$s" is not a valid path segment');
        }
        if (entries.any((e) => e.path == full)) throw RoutesRulesError('"$full" is listed twice');
        entries.add(RouteEntry(
          full,
          parent: parent,
          screen: r.screen,
          legacy: r.legacy,
          shell: r.shell,
          devOnly: r.devOnly,
          params: [for (final s in segments) if (s.startsWith(':')) s.substring(1)],
        ));
        walk(r.routes, full == '/' ? '' : full);
      }
    }

    walk(rules.routes, '');
    if (!entries.any((e) => e.path == rules.initial)) {
      throw RoutesRulesError('initial "${rules.initial}" is not a route');
    }
  }

  String get initial => rules.initial;

  Set<String> get screenNames => {for (final e in entries) if (e.screen != null) e.screen!};

  Set<String> get legacyNames => {for (final e in entries) if (e.legacy != null) e.legacy!};

  /// The route a concrete location (`/placed/abc123`) lands on, or null. Query strings are ignored.
  RouteEntry? match(String location) {
    final path = Uri.parse(location).path;
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    for (final e in entries) {
      final pattern = e.path.split('/').where((s) => s.isNotEmpty).toList();
      if (pattern.length != parts.length) continue;
      var ok = true;
      for (var i = 0; i < parts.length && ok; i++) {
        ok = pattern[i].startsWith(':') || pattern[i] == parts[i];
      }
      if (ok) return e;
    }
    return null;
  }

  /// Whether a `go:` template from a screen YAML (`/placed/{item.id}`) can land on a route. `{…}` stands for one
  /// path segment.
  bool acceptsTemplate(String template) =>
      match(template.replaceAll(RegExp(r'\{[^}]+\}'), 'x')) != null;
}
