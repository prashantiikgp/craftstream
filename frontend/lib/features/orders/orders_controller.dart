/// Orders placed from this device, newest first. There is no login, so the device remembers them (order_store,
/// rules in orders.yml): a copy of each is saved when it is placed and loaded on start, so Your orders and the
/// receipts survive closing the app; then each order is re-read from the API so the stored status is shown.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../data/generated/models.dart';
import '../../data/orders/order_store.dart';
import '../../data/providers.dart';

class PlacedOrder {
  final Order order;
  final String productTitle;
  final String artisanName;
  const PlacedOrder({required this.order, required this.productTitle, required this.artisanName});

  Map<String, Object?> toJson() =>
      {'order': order.toJson(), 'product_title': productTitle, 'artisan_name': artisanName};

  factory PlacedOrder.fromJson(Map<String, dynamic> json) => PlacedOrder(
        order: Order.fromJson(json['order'] as Map<String, dynamic>),
        productTitle: json['product_title'] as String,
        artisanName: json['artisan_name'] as String,
      );

  PlacedOrder withOrder(Order o) => PlacedOrder(order: o, productTitle: productTitle, artisanName: artisanName);
}

class OrdersController extends Notifier<List<PlacedOrder>> {
  @override
  List<PlacedOrder> build() {
    unawaited(_load());
    return const [];
  }

  OrderStore get _store => ref.read(orderStoreProvider);

  List<PlacedOrder> _trim(Iterable<PlacedOrder> orders) =>
      ref.read(appConfigProvider).orders.trim(orders, (p) => p.order.id);

  /// Saved orders join whatever was placed meanwhile; unreadable entries are skipped.
  Future<void> _load() async {
    final saved = <PlacedOrder>[];
    for (final entry in await _store.read()) {
      try {
        saved.add(PlacedOrder.fromJson(jsonDecode(entry) as Map<String, dynamic>));
      } catch (_) {
        // A copy from an older app version: forget it.
      }
    }
    if (!ref.mounted) return;
    state = _trim([...state, ...saved]);
    if (ref.read(appConfigProvider).orders.refreshOnStart) unawaited(_refresh());
  }

  /// Re-reads each order from the API; keeps the saved copy when offline or when the API no longer has it.
  Future<void> _refresh() async {
    final repo = ref.read(orderRepositoryProvider);
    for (final p in [...state]) {
      try {
        final fresh = await repo.get(p.order.id);
        if (!ref.mounted) return;
        state = [for (final o in state) o.order.id == fresh.id ? o.withOrder(fresh) : o];
      } catch (_) {
        // Offline or unknown: the saved copy stays.
      }
    }
    await _save();
  }

  Future<void> _save() => _store.write([for (final p in state) jsonEncode(p.toJson())]);

  void add(PlacedOrder placed) {
    state = _trim([placed, ...state]);
    unawaited(_save());
  }

  PlacedOrder? byId(String id) => state.where((p) => p.order.id == id).firstOrNull;
}

final ordersControllerProvider = NotifierProvider<OrdersController, List<PlacedOrder>>(OrdersController.new);
