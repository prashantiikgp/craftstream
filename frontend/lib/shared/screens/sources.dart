/// The data sources screen YAML can name with `data:`. This is the only list; screen_render_test checks every
/// screen's `data:` is here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/orders/orders_source.dart';
import 'screen_scope.dart';

typedef ScreenSource = ScreenData Function(WidgetRef ref, Map<String, String> params);

const Map<String, ScreenSource> screenSources = {
  'home': homeSource,
  'orders': ordersSource,
  'receipt': receiptSource,
};
