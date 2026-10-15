// Every inner screen can switch light/dark from its top bar, and the bar still fits a 360 px phone.
import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

void main() {
  late AppConfig config;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    config = await testConfig();
  });

  testWidgets('every screen with a top bar has the light/dark toggle, and it switches', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await pumpApp(tester, config, size: const Size(360, 640), location: '/');
    final toDark = find.bySemanticsLabel(str(config, 'theme.to_dark'));
    for (final location in ['/discover', '/product/p_01', '/product/p_01/buy', '/orders', '/studio', '/logs']) {
      container.read(routerProvider).go(location);
      await settle(tester);
      expect(toDark, findsOneWidget, reason: '$location has no theme toggle');
      expect(tester.takeException(), isNull, reason: '$location overflows at 360 px');
    }
    await tester.tap(toDark);
    await settle(tester);
    expect(container.read(themeChoiceProvider), ThemeMode.dark);
    expect(find.bySemanticsLabel(str(config, 'theme.to_light')), findsOneWidget);
    handle.dispose();
  });
}
