// Every screen renders on mock data at phone, tablet and desktop widths, in light and dark, without
// layout errors, and shows its key text.
import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

void main() {
  late AppConfig light, dark;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    light = await testConfig(mode: 'light');
    dark = await testConfig(mode: 'dark');
  });

  final screens = <String, List<String> Function(AppConfig)>{
    '/discover': (c) => [str(c, 'discover.title'), 'Hand-thrown clay mug'],
    '/orders': (c) => [str(c, 'orders.empty_title')],
    // Status tags use the eyebrow style, which theme.yml shows in capitals.
    '/studio': (c) => [str(c, 'studio.title'), 'Glazed serving bowl', str(c, 'status.failed').toUpperCase()],
    '/studio/new': (c) => [str(c, 'upload.video_empty_title'), str(c, 'upload.publish')],
    '/product/p_01': (c) => ['Hand-thrown clay mug', str(c, 'product.about')],
    '/product/p_01/buy': (c) => [str(c, 'checkout.title'), str(c, 'checkout.place_order')],
    '/': (c) => [str(c, 'home.buy_title'), str(c, 'home.sell_title'), str(c, 'home.orders')],
    // An order this device did not place: the receipt explains instead of showing an empty one.
    '/placed/ord_test': (c) => [str(c, 'placed.missing_title')],
  };
  const sizes = {'phone': Size(390, 844), 'tablet': Size(820, 1180), 'desktop': Size(1280, 900)};

  for (final MapEntry(key: path, value: expected) in screens.entries) {
    for (final MapEntry(key: device, value: size) in sizes.entries) {
      for (final mode in ['light', 'dark']) {
        testWidgets('$path · $device · $mode', (tester) async {
          final config = mode == 'light' ? light : dark;
          await pumpApp(tester, config, size: size, location: path);
          expect(tester.takeException(), isNull);
          for (final text in expected(config)) {
            expect(find.text(text, findRichText: true), findsWidgets, reason: '"$text" on $path');
          }
        });
      }
    }
  }

  testWidgets('Buy and Sell: the home doors lead to each side', (tester) async {
    final container = await pumpApp(tester, light, location: '/');
    await tester.tap(find.text(str(light, 'home.sell_title')));
    await settle(tester);
    expect(find.text(str(light, 'studio.title')), findsOneWidget);
    container.read(routerProvider).go('/');
    await settle(tester);
    await tester.tap(find.text(str(light, 'home.buy_title')));
    await settle(tester);
    expect(find.text(str(light, 'discover.title')), findsOneWidget);
  });
}
