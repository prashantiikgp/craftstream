/// How many orders the device keeps and in what order (orders.yml). Pure Dart.
library;

import '../../schemas/orders/orders_schema.dart';

class OrdersRulesError implements Exception {
  final String message;
  const OrdersRulesError(this.message);
  @override
  String toString() => 'orders.yml: $message';
}

class OrdersEngine {
  final OrdersSchema rules;

  OrdersEngine(this.rules) {
    if (rules.storageKey.trim().isEmpty) throw const OrdersRulesError('storage_key is empty');
    if (rules.keep < 1) throw const OrdersRulesError('keep must be at least 1');
  }

  String get storageKey => rules.storageKey;
  bool get refreshOnStart => rules.refreshOnStart;

  /// [items] newest first, without repeats (by [idOf]) and cut to `keep`.
  List<T> trim<T>(Iterable<T> items, String Function(T) idOf) {
    final seen = <String>{};
    return [
      for (final i in items)
        if (seen.add(idOf(i))) i,
    ].take(rules.keep).toList();
  }
}
