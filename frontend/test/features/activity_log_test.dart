// The Activity log screen on mock data: newest first, filter by group and level, one listing's own log, and
// the way back to all of it. Opened from Home.
import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/router.dart';
import 'package:craftstream/data/generated/models.dart';
import 'package:craftstream/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

void main() {
  late AppConfig c;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    c = await testConfig();
  });

  testWidgets('Home opens the log; filters narrow it; a listing has its own log', (tester) async {
    final container = await pumpApp(tester, c, size: const Size(1280, 1400), location: '/');
    await tester.tap(find.text(str(c, 'home.logs')));
    await settle(tester);
    expect(find.text(str(c, 'logs.subtitle')), findsOneWidget);
    final store = container.read(mockStoreProvider);
    final all = store.logs(limit: 1000).items;
    final more = all.length > c.activityLog.pageSize;
    final shown = more ? c.activityLog.pageSize : all.length;
    expect(find.text(str(c, more ? 'logs.count_more' : 'logs.count_many', {'count': shown})), findsOneWidget);

    // Only videos.
    // Chips use the eyebrow style, shown in capitals.
    await tester.tap(find.text(str(c, 'logs.group_video').toUpperCase()));
    await settle(tester);
    final videos = all.where((e) => e.group == 'video').length;
    expect(find.text(str(c, 'logs.count_many', {'count': videos})), findsOneWidget);

    // Only warnings: none in the sample data.
    await tester.tap(find.text(str(c, 'logs.level_warning').toUpperCase()).first);
    await settle(tester);
    expect(find.text(str(c, 'logs.empty_title')), findsOneWidget);

    // One listing's log, then back to all of it.
    final LogEntry newest = all.first;
    container.read(routerProvider).go('/logs/listing/${newest.productId}');
    await settle(tester);
    expect(find.text(str(c, 'logs.listing', {'id': newest.productId!})), findsWidgets);
    await tester.tap(find.text(str(c, 'logs.show_all')));
    await settle(tester);
    expect(find.text(str(c, 'logs.show_all')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an entry with details shows them', (tester) async {
    final container = await pumpApp(tester, c, size: const Size(1280, 1400), location: '/');
    container
        .read(mockStoreProvider)
        .log(
          'upload_interrupted',
          productId: 'p_01',
          source: 'app',
          details: const [LogDetail(key: 'reason', value: 'UploadInterrupted')],
        );
    container.read(routerProvider).go('/logs');
    await settle(tester);
    expect(find.text('UploadInterrupted'), findsNothing);
    await tester.tap(find.text('Connection dropped; the upload will resume'));
    await settle(tester);
    expect(find.text('UploadInterrupted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
