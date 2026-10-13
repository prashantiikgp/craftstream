// Every screen renders on mock data at phone, tablet and desktop widths, in light and dark, without
// layout errors, and shows its key text.
import 'package:craftstream/core/config.dart';
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
    '/studio': (c) => [str(c, 'studio.title'), 'Glazed serving bowl', str(c, 'status.failed')],
    '/studio/new': (c) => [str(c, 'upload.video_empty_title'), str(c, 'upload.publish')],
    '/product/p_01': (c) => ['Hand-thrown clay mug', str(c, 'product.about')],
    '/product/p_01/buy': (c) => [str(c, 'checkout.title'), str(c, 'checkout.place_order')],
    '/placed/ord_test': (c) => [str(c, 'placed.title')],
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

  testWidgets('phones get a bottom bar, desktops a rail', (tester) async {
    await pumpApp(tester, light, size: const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await pumpApp(tester, light, size: const Size(1280, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('the Buy/Sell switch moves between the buyer and artisan sides', (tester) async {
    await pumpApp(tester, light);
    await tester.tap(find.text(str(light, 'shell.role_artisan')));
    await settle(tester);
    expect(find.text(str(light, 'studio.title')), findsOneWidget);
    await tester.tap(find.text(str(light, 'shell.role_buyer')));
    await settle(tester);
    expect(find.text(str(light, 'discover.title')), findsOneWidget);
  });
}
