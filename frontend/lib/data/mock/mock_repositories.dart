/// Repository implementations backed by MockStore (MOCK_DATA=true).
library;

import '../generated/models.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/log_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/upload_repository.dart';
import '../upload/picked_video.dart';
import '../upload/video_picker.dart';
import '../../domain/dev/mock_engine.dart';
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

  @override
  Future<Order> get(String id) async {
    await _s.wait();
    return _s.order(id);
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

class MockLogRepository implements LogRepository {
  final MockStore _s;
  const MockLogRepository(this._s);

  @override
  Future<LogPage> page({String? group, String? level, String? productId, String? cursor, int? limit}) async {
    await _s.wait();
    return _s.logs(group: group, level: level, productId: productId, cursor: cursor, limit: limit);
  }

  @override
  Future<LogEntry> report(LogEntryCreate entry) async {
    await _s.wait();
    return _s.report(entry);
  }
}

/// Returns mock.yml's sample videos in turn (one fits the 15:00 limit, one does not), so both paths can be shown.
class MockVideoPicker implements VideoPicker {
  final MockEngine rules;
  int _picks = 0;
  MockVideoPicker(this.rules);

  @override
  Future<PickedVideo?> pick() async {
    final v = rules.videos[_picks++ % rules.videos.length];
    return PickedVideo(name: v.name, sizeBytes: v.sizeBytes, mimeType: v.mimeType, duration: rules.videoLength(v));
  }
}
