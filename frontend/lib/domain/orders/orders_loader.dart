/// Load assets/config/orders/orders.yml, validated by OrdersSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/orders/orders_schema.dart';

Future<OrdersSchema> loadOrdersRules({AssetBundle? bundle}) =>
    loadYamlAsset('orders/orders.yml', OrdersSchema.fromJson, bundle: bundle);
