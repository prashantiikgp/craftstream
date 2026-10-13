// The artisan upload against the real data layer (MOCK_DATA=false): the API repositories and the resumable
// uploader talk HTTP to a fake API + GCS session. The connection drops mid-chunk; the upload resumes from
// the offset the session confirms, then the product is polled until it is live. Then a buyer orders it.
import 'dart:typed_data';

import 'package:craftstream/core/config.dart';
import 'package:craftstream/data/api_provider.dart';
import 'package:craftstream/data/generated/models.dart';
import 'package:craftstream/data/providers.dart';
import 'package:craftstream/data/upload/picked_video.dart';
import 'package:craftstream/data/upload/video_picker.dart';
import 'package:craftstream/features/upload/upload_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_backend.dart';
import '../helpers/harness.dart';

/// A video held in memory that records every byte range the uploader asks for.
class _FakePicker implements VideoPicker {
  final int size;
  final reads = <(int, int)>[];
  _FakePicker(this.size);

  @override
  Future<PickedVideo?> pick() async => PickedVideo(
        name: 'kantha-stitching.mp4',
        sizeBytes: size,
        mimeType: 'video/mp4',
        duration: const Duration(minutes: 3, seconds: 20),
        read: (start, end) {
          reads.add((start, end));
          return Stream.value(Uint8List(end - start));
        },
      );
}

void main() {
  late AppConfig config;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    config = await testConfig(mockData: false);
  });

  testWidgets('chunked upload survives a drop, then polls until live; the order goes to the API', (tester) async {
    const size = kib256 * 3 + 5000;
    final server = FakeBackend(dropPuts: {1}, keptBlocksOnDrop: 0);
    final picker = _FakePicker(size);
    final container = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(config),
      httpClientProvider.overrideWithValue(server.client),
      videoPickerProvider.overrideWithValue(picker),
    ]);
    addTearDown(container.dispose);

    final upload = container.read(uploadControllerProvider.notifier)
      ..setTitle('Kantha cushion cover')
      ..setDescription('Running stitch on old cotton saris.')
      ..setPrice('1450')
      ..setArtisanName('Rina Das')
      ..toggleTag('textiles');
    await upload.pickVideo();
    expect(await upload.publish(), isTrue);

    for (var i = 0; i < 60 && container.read(uploadControllerProvider).phase != UploadPhase.live; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final state = container.read(uploadControllerProvider);
    expect(state.phase, UploadPhase.live);
    expect(state.sent, size);
    expect(server.received, size);

    // Chunks never exceed the ticket's size: the whole file is never read at once.
    expect(picker.reads.every((r) => r.$2 - r.$1 <= kib256), isTrue);
    // PUT #1 dropped; the uploader asked what arrived and re-sent that chunk.
    expect(server.contentRanges, [
      'bytes 0-262143/791432',
      'bytes 262144-524287/791432',
      'bytes */791432',
      'bytes 262144-524287/791432',
      'bytes 524288-786431/791432',
      'bytes 786432-791431/791432',
    ]);
    expect(server.product!.videoStatus, 'ready');

    final order = await container
        .read(orderRepositoryProvider)
        .place(const OrderCreate(productId: 'p_new', buyerName: 'Asha', quantity: 1));
    expect(order.status, 'placed');
    expect(server.orders.single, {'product_id': 'p_new', 'buyer_name': 'Asha', 'quantity': 1});
  });
}
