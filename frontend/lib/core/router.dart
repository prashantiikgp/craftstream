/// Routes. Buyer and artisan destinations live inside the shell (navigation bar or rail); product,
/// checkout and the order confirmation are full pages. Dev-only screens redirect away unless DEV_TOOLS is on.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/checkout/checkout_screen.dart';
import '../features/checkout/order_placed_screen.dart';
import '../features/design_catalog/design_catalog_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/product/product_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/studio/studio_screen.dart';
import '../features/upload/upload_screen.dart';
import 'config.dart';

NoTransitionPage<void> _tab(GoRouterState state, Widget Function() build) =>
    NoTransitionPage(key: state.pageKey, child: build());

final routerProvider = Provider<GoRouter>((ref) {
  final devTools = ref.watch(appConfigProvider).env.devTools;
  return GoRouter(
    initialLocation: '/discover',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/discover'),
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/discover', pageBuilder: (_, s) => _tab(s, () => const DiscoverScreen())),
          GoRoute(path: '/orders', pageBuilder: (_, s) => _tab(s, () => const OrdersScreen())),
          GoRoute(path: '/studio', pageBuilder: (_, s) => _tab(s, () => const StudioScreen())),
          GoRoute(path: '/studio/new', pageBuilder: (_, s) => _tab(s, () => const UploadScreen())),
        ],
      ),
      GoRoute(
        path: '/product/:id',
        builder: (_, s) => ProductScreen(productId: s.pathParameters['id']!),
        routes: [
          GoRoute(path: 'buy', builder: (_, s) => CheckoutScreen(productId: s.pathParameters['id']!)),
        ],
      ),
      GoRoute(path: '/placed/:orderId', builder: (_, s) => OrderPlacedScreen(orderId: s.pathParameters['orderId']!)),
      GoRoute(
        path: '/catalog',
        redirect: (_, _) => devTools ? null : '/',
        builder: (_, _) => const DesignCatalogScreen(),
      ),
    ],
  );
});
