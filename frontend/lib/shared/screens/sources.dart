/// The data sources screen YAML can name with `data:`. This is the only list; screen_render_test checks every
/// screen's `data:` is here and every `{call: name}` it uses is one the source declares.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/discover/discover_source.dart';
import '../../features/orders/orders_source.dart';
import 'screen_scope.dart';

typedef ScreenSource = ScreenData Function(WidgetRef ref, Map<String, String> params);

class SourceDef {
  final ScreenSource build;

  /// The `{call: name}` actions this source answers.
  final Set<String> calls;
  const SourceDef(this.build, {this.calls = const {}});
}

const Map<String, SourceDef> screenSources = {
  'home': SourceDef(homeSource),
  'orders': SourceDef(ordersSource),
  'receipt': SourceDef(receiptSource),
  'discover': SourceDef(discoverSource, calls: discoverCalls),
};
