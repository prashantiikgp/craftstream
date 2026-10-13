// The buyer journey on mock data: search -> product -> checkout -> "Order placed" -> Orders.
import 'package:craftstream/core/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

void main() {
  late AppConfig c;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    c = await testConfig();
  });

  testWidgets('search, open a product, order it', (tester) async {
    await pumpApp(tester, c);

    // Search (debounced) narrows the grid.
    await tester.enterText(find.byType(TextField), 'clay mug');
    await tester.pump(c.filters.debounce + const Duration(milliseconds: 50));
    await settle(tester);
    expect(find.text(str(c, 'discover.count_one')), findsOneWidget);

    await tester.tap(find.text('Hand-thrown clay mug'));
    await settle(tester);
    expect(find.text(str(c, 'product.about')), findsOneWidget);

    await tester.tap(find.text(str(c, 'product.buy')).first);
    await settle(tester);
    expect(find.text(str(c, 'checkout.title')), findsOneWidget);

    // Too short a name is caught before anything is sent.
    await tester.tap(find.text(str(c, 'checkout.place_order')));
    await settle(tester);
    expect(find.text(str(c, 'checkout.name_too_short', {'min': 2})), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Asha Rao');
    await tester.tap(find.byTooltip(str(c, 'checkout.increase')));
    await settle(tester);
    expect(find.text('₹900'), findsOneWidget); // 2 × ₹450

    await tester.tap(find.text(str(c, 'checkout.place_order')));
    await settle(tester);
    expect(find.text(str(c, 'placed.title')), findsOneWidget);
    expect(find.text(str(c, 'placed.message', {'artisan': 'Meera Devi'})), findsOneWidget);

    await tester.tap(find.text(str(c, 'placed.see_orders')));
    await settle(tester);
    expect(find.text('Hand-thrown clay mug'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tag on the product page filters Discover', (tester) async {
    await pumpApp(tester, c, location: '/product/p_07');
    await tester.ensureVisible(find.text('dhokra'));
    await tester.tap(find.text('dhokra'));
    await settle(tester);
    expect(find.text(str(c, 'discover.tag_filter', {'tag': 'dhokra'})), findsOneWidget);
    expect(find.text('Dhokra brass elephant'), findsOneWidget);
  });
}
