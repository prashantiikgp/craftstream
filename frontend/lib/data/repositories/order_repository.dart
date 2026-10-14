/// Placing an order (the flow ends there: no payment, no shipping) and reading one back by id.
library;

import '../generated/api_client.dart';
import '../generated/models.dart';

abstract interface class OrderRepository {
  Future<Order> place(OrderCreate order);
  Future<Order> get(String id);
}

class ApiOrderRepository implements OrderRepository {
  final ApiClient _api;
  const ApiOrderRepository(this._api);

  @override
  Future<Order> place(OrderCreate order) => _api.createOrder(order);

  @override
  Future<Order> get(String id) => _api.getOrder(id);
}
