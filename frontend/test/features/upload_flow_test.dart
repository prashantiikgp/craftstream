// The artisan journey on mock data: fill the form, pick a video (too long is refused), upload in chunks,
// survive a dropped connection, then wait for processing until the product is live.
import 'dart:async';

import 'package:craftstream/features/upload/upload_controller.dart';
import 'package:craftstream/core/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

/// Each mock chunk takes this long, so the test can act mid-upload.
const chunk = Duration(milliseconds: 100);

void main() {
  late AppConfig c;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    c = await testConfig();
  });

  testWidgets('new product: validate, upload with a drop, go live', (tester) async {
    final container = await pumpApp(tester, c, size: const Size(1280, 1400), location: '/studio/new', chunkDelay: chunk);

    // Publishing an empty form shows what is missing.
    await tester.tap(find.text(str(c, 'upload.publish')));
    await settle(tester);
    expect(find.text(str(c, 'upload.fix_title')), findsOneWidget);
    expect(find.text(str(c, 'upload.video_required')), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Clay teapot');
    await tester.enterText(fields.at(1), 'Thrown and fired twice.');
    await tester.enterText(fields.at(2), '1450');
    await tester.tap(find.text('pottery'));
    await settle(tester);

    // First pick fits the 15:00 limit.
    await tester.tap(find.text(str(c, 'upload.choose_video')));
    await settle(tester);
    expect(find.text(str(c, 'upload.check_ok_title')), findsOneWidget);

    // The second sample is 18:05 and is refused before any upload.
    await tester.tap(find.text(str(c, 'upload.change_video')));
    await settle(tester);
    expect(find.text(str(c, 'upload.check_too_long_title')), findsOneWidget);
    await tester.tap(find.text(str(c, 'upload.publish')));
    await settle(tester);
    expect(container.read(uploadControllerProvider).phase, UploadPhase.editing);

    await tester.tap(find.text(str(c, 'upload.change_video')));
    await settle(tester);
    await tester.tap(find.text(str(c, 'upload.publish')));
    await tester.pump();
    await tester.pump();
    expect(container.read(uploadControllerProvider).busy, isTrue);

    // Drop the connection mid-upload: it backs off, asks for the confirmed offset and carries on.
    await settle(tester, frames: 3);
    container.read(uploadControllerProvider.notifier).simulateDrop();
    await settle(tester, frames: 3);
    expect(container.read(uploadControllerProvider).phase, UploadPhase.reconnecting);
    expect(find.text(str(c, 'upload.reconnecting_title')), findsOneWidget);
    await tester.pump(c.upload.backoff(1));
    await settle(tester, frames: 120); // ~52 chunks of 100 ms; the first status poll is 3 s after the last

    final s = container.read(uploadControllerProvider);
    expect(s.sent, s.total);
    expect(s.phase, UploadPhase.processing);
    expect(find.text(str(c, 'upload.processing_title')), findsOneWidget);

    await tester.pump(c.upload.statusPollInterval);
    await settle(tester);
    expect(container.read(uploadControllerProvider).phase, UploadPhase.live);
    expect(find.text(str(c, 'upload.live_title')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause stops sending; resume carries on', (tester) async {
    final container = await pumpApp(tester, c, location: '/studio/new', chunkDelay: chunk);
    final ctrl = container.read(uploadControllerProvider.notifier)
      ..setTitle('Brass bell')
      ..setDescription('Cast and polished.')
      ..setPrice('800');
    await ctrl.pickVideo();
    unawaited(ctrl.publish());
    await settle(tester, frames: 3);
    ctrl.pause();
    await settle(tester, frames: 3); // the chunk in flight still lands
    final paused = container.read(uploadControllerProvider);
    expect(paused.phase, UploadPhase.paused);
    await settle(tester, frames: 10);
    expect(container.read(uploadControllerProvider).sent, paused.sent);
    ctrl.resume();
    await settle(tester, frames: 120);
    expect(container.read(uploadControllerProvider).phase, UploadPhase.processing);
    await tester.pump(c.upload.statusPollInterval);
    await settle(tester);
  });
}
