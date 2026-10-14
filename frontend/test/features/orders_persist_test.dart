// Orders survive closing the app: a placed order is saved on the device (order_store, orders.yml) and comes back
// in Your orders and on its receipt when the app starts again; entries the app cannot read are skipped.
import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/router.dart';
import 'package:craftstream/data/orders/order_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

void main() {
  late AppConfig c;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    c = await testConfig();
  });

  testWidgets('a placed order is still there after a restart', (tester) async {
    final store = MemoryOrderStore();
    var container = await pumpApp(tester, c, location: '/product/p_01/buy', orderStore: store);
    // Place it the way a buyer does (checkout adds it to Your orders, which saves it).
    await tester.enterText(find.byType(TextField), 'Asha');
    await tester.tap(find.text(str(c, 'checkout.place_order')));
    await settle(tester);
    expect(find.text(str(c, 'placed.title')), findsOneWidget);
    expect(store.entries, hasLength(1));

    // "Restart": a fresh app with the same device storage.
    await tester.pumpWidget(const SizedBox());
    container = await pumpApp(tester, c, location: '/orders', orderStore: store);
    await settle(tester);
    expect(find.text('Hand-thrown clay mug'), findsOneWidget);
    expect(find.text(str(c, 'orders.empty_title')), findsNothing);

    final saved = store.entries.single;
    final id = RegExp(r'"id":"([^"]+)"').firstMatch(saved)!.group(1)!;
    container.read(routerProvider).go('/placed/$id');
    await settle(tester);
    expect(find.text(str(c, 'placed.title')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copies the app cannot read are skipped', (tester) async {
    final store = MemoryOrderStore()..entries = ['not json', '{"order": {}}'];
    await pumpApp(tester, c, location: '/orders', orderStore: store);
    await settle(tester);
    expect(find.text(str(c, 'orders.empty_title')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
