/// Screens from ui/screens/*.yml, with every brick checked against the catalogue (bricks_engine) and the rest of
/// the config (strings, icons, routes …). Pure Dart: lib/shared/screens/screen_host.dart draws a [ScreenSpec].
library;

import '../../schemas/ui/screen_schema.dart';
import 'bricks_engine.dart';

class ScreenRulesError implements Exception {
  final String message;
  const ScreenRulesError(this.message);
  @override
  String toString() => 'ui/screens: $message';
}

class ScreenSpec {
  final String name, about, gap;
  final String? data, backdrop;
  final ScreenWidth width;
  final bool fill;
  final List<BrickNode> top, body, bottom, empty, error;
  const ScreenSpec({
    required this.name,
    required this.about,
    required this.gap,
    required this.data,
    required this.backdrop,
    required this.width,
    required this.fill,
    required this.top,
    required this.body,
    required this.bottom,
    required this.empty,
    required this.error,
  });

  /// Every brick in the screen, children included (for tests and the catalog).
  Iterable<BrickNode> get allBricks sync* {
    Iterable<BrickNode> walk(BrickNode n) sync* {
      yield n;
      for (final v in n.props.values) {
        if (v is BrickNode) yield* walk(v);
        if (v is List<BrickNode>) {
          for (final c in v) {
            yield* walk(c);
          }
        }
      }
    }

    for (final n in [...top, ...body, ...bottom, ...empty, ...error]) {
      yield* walk(n);
    }
  }
}

class ScreenEngine {
  final Map<String, ScreenSchema> rules;
  final Map<String, ScreenSpec> _screens = {};

  /// Parses and checks every screen. [backdrops] are the backdrop names in ui/art.yml.
  ScreenEngine(this.rules, BricksEngine bricks, BrickRefs refs, {required Set<String> backdrops}) {
    final name = RegExp(r'^[a-z][a-z0-9_]*$');
    rules.forEach((screen, s) {
      if (!name.hasMatch(screen)) throw ScreenRulesError('$screen.yml: file names are snake_case');
      if (!refs.spaces.contains(s.gap)) throw ScreenRulesError('$screen.gap: unknown spacing step "${s.gap}"');
      if (s.backdrop != null && !backdrops.contains(s.backdrop)) {
        throw ScreenRulesError('$screen.backdrop: "${s.backdrop}" is not in ui/art.yml backdrops');
      }
      if (s.body.isEmpty) throw ScreenRulesError('$screen.body is empty');
      List<BrickNode> part(String which, List<Object?> nodes) =>
          [for (final (i, n) in nodes.indexed) bricks.parse(n, '$screen.$which[$i]', refs)];
      final spec = ScreenSpec(
        name: screen,
        about: s.about,
        gap: s.gap,
        data: s.data,
        backdrop: s.backdrop,
        width: s.width,
        fill: s.fill,
        top: part('top', s.top),
        body: part('body', s.body),
        bottom: part('bottom', s.bottom),
        empty: part('empty', s.empty),
        error: part('error', s.error),
      );
      if (!s.fill && spec.allBricks.any((b) => b.brick == 'spacer')) {
        throw ScreenRulesError('$screen: a spacer only works with fill: true');
      }
      _screens[screen] = spec;
    });
  }

  Iterable<String> get names => _screens.keys;

  bool has(String name) => _screens.containsKey(name);

  ScreenSpec screen(String name) => _screens[name] ?? (throw ScreenRulesError('no screen "$name" in ui/screens/'));
}
