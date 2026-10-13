/// Orders placed from this device in this session. There is no orders endpoint and no login, so this
/// list lives in memory only; the order itself is stored by the API.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/generated/models.dart';

class PlacedOrder {
  final Order order;
  final String productTitle;
  final String artisanName;
  const PlacedOrder({required this.order, required this.productTitle, required this.artisanName});
}

class OrdersController extends Notifier<List<PlacedOrder>> {
  @override
  List<PlacedOrder> build() => const [];

  void add(PlacedOrder placed) => state = [placed, ...state];

  PlacedOrder? byId(String id) => state.where((p) => p.order.id == id).firstOrNull;
}

final ordersControllerProvider = NotifierProvider<OrdersController, List<PlacedOrder>>(OrdersController.new);
