// Every screen YAML draws without errors at phone, tablet and desktop sizes, in light and dark, with data and
// without it. This stands in for the compile-time checks screens lost when they moved out of Dart: a brick with
// no builder, a missing style key in bricks.yml, a binding to nothing or an overflow fails here.
import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/router.dart';
import 'package:craftstream/data/generated/models.dart';
import 'package:craftstream/features/orders/orders_controller.dart';
import 'package:craftstream/shared/bricks/bricks.dart';
import 'package:craftstream/shared/screens/screen_host.dart';
import 'package:craftstream/shared/screens/sources.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

final sampleOrder = PlacedOrder(
  order: Order(
    id: 'ord_test',
    productId: 'p_01',
    buyerName: 'Asha',
    quantity: 2,
    total: 900,
    currency: 'INR',
    status: 'placed',
    createdAt: DateTime(2026, 10, 14),
  ),
  productTitle: 'Hand-thrown clay mug',
  artisanName: 'Meera Devi',
);

void main() {
  // Loaded outside testWidgets: asset loading is real I/O and never completes on the test's fake clock.
  final configs = <String, AppConfig>{};
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final mode in ['light', 'dark']) {
      configs[mode] = await testConfig(mode: mode);
    }
  });

  test('every brick in bricks.yml has a builder, and every builder a brick', () async {
    final config = configs['light']!;
    expect(brickBuilders.keys.toSet(), config.bricks.names.toSet());
  });

  test('every screen\'s data source exists', () async {
    final config = configs['light']!;
    for (final name in config.screens.names) {
      final data = config.screens.screen(name).data;
      if (data != null) expect(screenSources.keys, contains(data), reason: '$name.yml data: $data');
    }
  });

  const sizes = {'phone': Size(390, 844), 'small phone': Size(360, 640), 'tablet': Size(820, 1180), 'desktop': Size(1280, 900)};

  for (final mode in ['light', 'dark']) {
    for (final MapEntry(key: device, value: size) in sizes.entries) {
      for (final withOrders in [true, false]) {
        testWidgets('screens · $device · $mode · ${withOrders ? 'with orders' : 'no orders'}', (tester) async {
          final config = configs[mode]!;
          final container = await pumpApp(tester, config, size: size, location: '/');
          if (withOrders) container.read(ordersControllerProvider.notifier).add(sampleOrder);
          for (final name in config.screens.names) {
            final route = config.routes.entries.firstWhere((e) => e.screen == name);
            final location = route.path.replaceAllMapped(RegExp(r':[a-z_]+'), (_) => sampleOrder.order.id);
            container.read(routerProvider).go(location);
            await settle(tester);
            expect(tester.takeException(), isNull, reason: '$name at $location');
            expect(find.byType(ScreenHost), findsOneWidget, reason: '$name at $location');
          }
        });
      }
    }
  }
}
