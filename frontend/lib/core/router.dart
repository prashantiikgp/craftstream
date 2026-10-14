/// The GoRouter, built from assets/config/app/routes.yml. A route shows a screen YAML through ScreenHost, or a
/// v1 Dart screen listed in [legacyScreens] until it moves to YAML. Dev-only routes redirect home unless DEV_TOOLS
/// is on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/app/routes_engine.dart';
import '../features/design_catalog/design_catalog_screen.dart';
import '../shared/screens/screen_host.dart';
import 'config.dart';

/// v1 screens by the name routes.yml gives them (`legacy: discover`). Delete an entry when its screen YAML lands.
final legacyScreens = <String, Widget Function(GoRouterState state)>{
  'design_catalog': (_) => const DesignCatalogScreen(),
};

final routerProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(appConfigProvider);
  final routes = config.routes;
  final missing = routes.legacyNames.difference(legacyScreens.keys.toSet());
  if (missing.isNotEmpty) throw StateError('routes.yml names v1 screens router.dart does not know: $missing');

  Widget show(RouteEntry e, GoRouterState s) =>
      e.screen != null ? ScreenHost(name: e.screen!, params: s.pathParameters) : legacyScreens[e.legacy!]!(s);

  String? guard(RouteEntry e) => e.devOnly && !config.env.devTools ? routes.initial : null;

  // Rebuild the nesting routes.yml declares, so a nested route (`/product/:id/buy`) keeps its parent below it.
  List<RouteBase> build(String parent) => [
        for (final e in routes.entries.where((e) => e.parent == parent))
          GoRoute(
            path: e.relativePath,
            redirect: (_, _) => guard(e),
            pageBuilder: (_, s) => MaterialPage(key: s.pageKey, child: show(e, s)),
            routes: build(e.path),
          ),
      ];

  return GoRouter(initialLocation: routes.initial, routes: build(''));
});
