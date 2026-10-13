/// In-app fake backend for MOCK_DATA=true: believable products, the same search rules as the API
/// (ready products only, every word must match, tag filter), orders and a simulated resumable upload.
/// Small delays make loading states visible. Nothing here is used when MOCK_DATA=false.
library;

import '../generated/models.dart';
import '../upload/picked_video.dart';
import 'mock_products.dart';

class MockNotFound implements Exception {
  final String id;
  const MockNotFound(this.id);
  @override
  String toString() => 'No product $id';
}

class MockStore {
  final Duration latency;
  final Duration chunkDelay;

  /// How long a finished upload stays "processing" before it turns ready.
  final Duration processingTime;

  final Map<String, Product> _products = {for (final p in mockProducts) p.id: p};
  final List<String> _mine = [...mockMyProductIds];
  final Map<String, int> _confirmed = {};
  final Map<String, DateTime> _readyAt = {};
  int _seq = 0;

  MockStore({
    this.latency = const Duration(milliseconds: 450),
    this.chunkDelay = const Duration(milliseconds: 140),
    this.processingTime = const Duration(seconds: 8),
  });

  Future<void> wait([Duration? d]) => Future.delayed(d ?? latency);

  // ---- catalog

  ProductPage search({String? q, String? tag, String? cursor, int? limit}) {
    final words = (q ?? '').toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final hits = _products.values.where((p) {
      if (p.videoStatus != 'ready') return false;
      if (tag != null && !p.tags.contains(tag)) return false;
      final index = _wordsOf(p);
      return words.every((w) => index.any((i) => i.startsWith(w)));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // Same paging as the API (catalog_service.search): the cursor is the last id of the previous page;
    // an unknown cursor gives an empty page.
    var rest = hits;
    if (cursor != null && cursor.isNotEmpty) {
      final at = hits.indexWhere((p) => p.id == cursor);
      rest = at < 0 ? [] : hits.sublist(at + 1);
    }
    final size = limit ?? 24;
    final page = rest.take(size).toList();
    final next = rest.length > size ? page.last.id : null;
    return ProductPage(items: [for (final p in page) summaryOf(p)], nextCursor: next);
  }

  Product product(String id) {
    final p = _products[id];
    if (p == null) throw MockNotFound(id);
    return _advance(p);
  }

  List<String> tags() {
    final counts = <String, int>{};
    for (final p in _products.values.where((p) => p.videoStatus == 'ready')) {
      for (final t in p.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    return counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  }

  // ---- orders

  Order placeOrder(OrderCreate body) {
    final p = product(body.productId);
    if (p.videoStatus != 'ready') throw StateError('product is not ready');
    _seq++;
    return Order(
      id: 'ord_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$_seq',
      productId: p.id,
      buyerName: body.buyerName,
      quantity: body.quantity,
      total: (p.price * body.quantity * 100).round() / 100,
      currency: p.currency,
      status: 'placed',
      createdAt: DateTime.now(),
    );
  }

  // ---- uploads

  UploadPolicy get policy => const UploadPolicy(
        maxDurationSeconds: 900,
        allowedMimeTypes: ['video/mp4', 'video/quicktime', 'video/webm', 'video/x-matroska', 'video/3gpp'],
        chunkSizeBytes: 8 * 1024 * 1024,
      );

  UploadTicket createListing(ProductCreate body) {
    _seq++;
    final p = Product(
      id: 'p_new$_seq',
      title: body.title,
      description: body.description,
      price: body.price,
      currency: body.currency,
      tags: body.tags,
      artisanName: body.artisanName,
      videoStatus: 'awaiting_upload',
      createdAt: DateTime.now(),
    );
    _products[p.id] = p;
    _mine.insert(0, p.id);
    return UploadTicket(
      product: p,
      uploadUrl: 'mock://uploads/${p.id}',
      uploadMethod: 'PUT',
      chunkSizeBytes: policy.chunkSizeBytes,
    );
  }

  int sendChunk(UploadTicket ticket, PickedVideo video, int offset, int length) {
    final id = ticket.product.id;
    final confirmed = offset + length;
    _confirmed[id] = confirmed;
    if (confirmed >= video.sizeBytes) {
      _products[id] = _withStatus(_products[id]!, 'processing');
      _readyAt[id] = DateTime.now().add(processingTime);
    }
    return confirmed;
  }

  int confirmedOffset(UploadTicket ticket) => _confirmed[ticket.product.id] ?? 0;

  List<Product> myProducts() => [for (final id in _mine) product(id)];

  // ---- helpers

  /// Processing turns ready once its time has passed (checked on read, so there are no timers).
  Product _advance(Product p) {
    final at = _readyAt[p.id];
    if (p.videoStatus == 'processing' && at != null && !DateTime.now().isBefore(at)) {
      final ready = _withStatus(p, 'ready', hlsUrl: 'mock://media/${p.id}/master.m3u8');
      _products[p.id] = ready;
      return ready;
    }
    return p;
  }

  static Set<String> _wordsOf(Product p) => {
        for (final text in [p.title, p.description, p.artisanName, ...p.tags])
          ...text.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty),
      };

  static ProductSummary summaryOf(Product p) => ProductSummary(
        id: p.id,
        title: p.title,
        price: p.price,
        currency: p.currency,
        tags: p.tags,
        artisanName: p.artisanName,
        thumbnailUrl: p.thumbnailUrl,
      );

  static Product _withStatus(Product p, String status, {String? hlsUrl}) => Product(
        id: p.id,
        title: p.title,
        description: p.description,
        price: p.price,
        currency: p.currency,
        tags: p.tags,
        artisanName: p.artisanName,
        videoStatus: status,
        hlsUrl: hlsUrl ?? p.hlsUrl,
        thumbnailUrl: p.thumbnailUrl,
        createdAt: p.createdAt,
      );
}
