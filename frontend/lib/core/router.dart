/// The GoRouter, built from assets/config/app/routes.yml: every route shows a screen YAML through ScreenHost.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/screens/screen_host.dart';
import 'config.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(appConfigProvider);
  final routes = config.routes;

  // Rebuild the nesting routes.yml declares, so a nested route (`/product/:id/buy`) keeps its parent below it.
  List<RouteBase> build(String parent) => [
        for (final e in routes.entries.where((e) => e.parent == parent))
          GoRoute(
            path: e.relativePath,
            pageBuilder: (_, s) =>
                MaterialPage(key: s.pageKey, child: ScreenHost(name: e.screen, params: s.pathParameters)),
            routes: build(e.path),
          ),
      ];

  return GoRouter(initialLocation: config.app.initialRoute, routes: build(''));
});
