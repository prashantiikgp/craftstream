/// Repository implementations backed by MockStore (MOCK_DATA=true).
library;

import '../generated/models.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/upload_repository.dart';
import '../upload/picked_video.dart';
import '../upload/video_picker.dart';
import 'mock_store.dart';

class MockCatalogRepository implements CatalogRepository {
  final MockStore _s;
  const MockCatalogRepository(this._s);

  @override
  Future<ProductPage> search({String? q, String? tag, String? cursor, int? limit}) async {
    await _s.wait();
    return _s.search(q: q, tag: tag, cursor: cursor, limit: limit);
  }

  @override
  Future<Product> product(String id) async {
    await _s.wait();
    return _s.product(id);
  }

  @override
  Future<List<String>> tags() async {
    await _s.wait();
    return _s.tags();
  }
}

class MockOrderRepository implements OrderRepository {
  final MockStore _s;
  const MockOrderRepository(this._s);

  @override
  Future<Order> place(OrderCreate order) async {
    await _s.wait();
    return _s.placeOrder(order);
  }
}

class MockUploadRepository implements UploadRepository {
  final MockStore _s;
  const MockUploadRepository(this._s);

  @override
  Future<UploadPolicy> policy() async {
    await _s.wait();
    return _s.policy;
  }

  @override
  Future<UploadTicket> createListing(ProductCreate body) async {
    await _s.wait();
    return _s.createListing(body);
  }

  @override
  Future<int> sendChunk(UploadTicket ticket, PickedVideo video, int offset, int length) async {
    await _s.wait(_s.chunkDelay);
    return _s.sendChunk(ticket, video, offset, length);
  }

  @override
  Future<int> confirmedOffset(UploadTicket ticket, PickedVideo video) async {
    await _s.wait();
    return _s.confirmedOffset(ticket);
  }

  @override
  Future<Product> status(String productId) async {
    await _s.wait();
    return _s.product(productId);
  }

  @override
  Future<List<Product>> myProducts() async {
    await _s.wait();
    return _s.myProducts();
  }
}

/// Alternates between a clip that fits the 15:00 limit and one that does not, so both paths can be shown.
class MockVideoPicker implements VideoPicker {
  int _picks = 0;

  static const samples = [
    PickedVideo(name: 'clay-mug-process.mp4', sizeBytes: 412 * 1024 * 1024, mimeType: 'video/mp4',
        duration: Duration(minutes: 12, seconds: 40)),
    PickedVideo(name: 'loom-full-day.mov', sizeBytes: 2150 * 1024 * 1024, mimeType: 'video/quicktime',
        duration: Duration(minutes: 18, seconds: 5)),
  ];

  @override
  Future<PickedVideo?> pick() async => samples[_picks++ % samples.length];
}
