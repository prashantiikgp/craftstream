/// Shape of assets/config/orders/orders.yml: how the device remembers its orders.
library;

import 'package:json_annotation/json_annotation.dart';

part 'orders_schema.g.dart';

@JsonSerializable()
class OrdersSchema {
  final String storageKey;
  final int keep;
  final bool refreshOnStart;

  const OrdersSchema({required this.storageKey, required this.keep, required this.refreshOnStart});

  factory OrdersSchema.fromJson(Map<String, dynamic> json) => _$OrdersSchemaFromJson(json);
}
