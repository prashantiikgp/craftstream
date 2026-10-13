/// Placing an order. The flow ends here (no payment, no shipping).
library;

import '../generated/api_client.dart';
import '../generated/models.dart';

abstract interface class OrderRepository {
  Future<Order> place(OrderCreate order);
}

class ApiOrderRepository implements OrderRepository {
  final ApiClient _api;
  const ApiOrderRepository(this._api);

  @override
  Future<Order> place(OrderCreate order) => _api.createOrder(order);
}
