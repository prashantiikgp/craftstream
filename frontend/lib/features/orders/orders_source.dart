/// Data for the YAML screens about orders (home's count, Your orders, Order placed). Field names are the Order
/// model's (models/order.yml), plus product_title and artisan_name from the product the order was for.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/screens/screen_scope.dart';
import 'orders_controller.dart';

Map<String, Object?> orderView(PlacedOrder p) => {
      ...p.order.toJson(),
      'product_title': p.productTitle,
      'artisan_name': p.artisanName,
    };

/// home: `orders.count`.
ScreenData homeSource(WidgetRef ref, Map<String, String> params) =>
    ScreenData.ready({'orders': {'count': ref.watch(ordersControllerProvider).length}});

/// orders: `orders.items` (newest first), `orders.count`; empty when there are none.
ScreenData ordersSource(WidgetRef ref, Map<String, String> params) {
  final orders = ref.watch(ordersControllerProvider);
  return ScreenData(orders.isEmpty ? SourceState.empty : SourceState.ready, {
    'orders': {'items': [for (final o in orders) orderView(o)], 'count': orders.length},
  });
}

/// receipt: `order` for params.order_id; empty when this device has no such order.
ScreenData receiptSource(WidgetRef ref, Map<String, String> params) {
  ref.watch(ordersControllerProvider);
  final placed = ref.read(ordersControllerProvider.notifier).byId(params['order_id'] ?? '');
  return placed == null ? const ScreenData(SourceState.empty) : ScreenData.ready({'order': orderView(placed)});
}
