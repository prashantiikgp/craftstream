/// Routes. Dev-only screens redirect away unless DEV_TOOLS is on.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/design_catalog/design_catalog_screen.dart';
import '../features/legacy/search_screen.dart';
import 'config.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final devTools = ref.watch(appConfigProvider).env.devTools;
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: '/catalog',
        redirect: (_, _) => devTools ? null : '/',
        builder: (_, _) => const DesignCatalogScreen(),
      ),
    ],
  );
});
