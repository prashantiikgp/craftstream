/// In-app fake backend for MOCK_DATA=true: believable products, the same search rules as the API
/// (ready products only, every word must match, tag filter), orders and a simulated resumable upload.
/// Small delays make loading states visible. It keeps an activity log the way the API does (a few entries
/// for the sample products, then one per step). Nothing here is used when MOCK_DATA=false.
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
  }) {
    for (final p in mockProducts) {
      log('listing_created', productId: p.id, at: p.createdAt);
      if (p.videoStatus == 'ready') log('transcode_succeeded', productId: p.id, at: p.createdAt.add(processingTime));
    }
  }

  Future<void> wait([Duration? d]) => Future.delayed(d ?? latency);

  // ---- catalog

  ProductPage search({String? q, String? tag, String? cursor, int? limit}) {
    final words = (q ?? '').toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final hits = _products.values.where((p) {
      if (p.videoStatus != 'ready') return false;
      if (tag != null && !p.tags.contains(tag)) return false;
      final index = _wordsOf(p);
      return words.every((w) => index.any((i) => i.startsWith(w)));
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  final Map<String, Order> _orders = {};

  Order order(String id) => _orders[id] ?? (throw StateError('no order $id'));

  Order placeOrder(OrderCreate body) {
    final p = product(body.productId);
    if (p.videoStatus != 'ready') throw StateError('product is not ready');
    _seq++;
    final order = Order(
      id: 'ord_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$_seq',
      productId: p.id,
      buyerName: body.buyerName,
      quantity: body.quantity,
      total: (p.price * body.quantity * 100).round() / 100,
      currency: p.currency,
      status: 'placed',
      createdAt: DateTime.now(),
    );
    log(
      'order_placed',
      productId: p.id,
      orderId: order.id,
      details: [
        LogDetail(key: 'quantity', value: '${order.quantity}'),
        LogDetail(key: 'total', value: '${order.total}'),
      ],
    );
    return _orders[order.id] = order;
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
    log('listing_created', productId: p.id);
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
      log(
        'upload_received',
        productId: id,
        details: [LogDetail(key: 'size', value: '${video.sizeBytes}')],
      );
      log('transcode_submitted', productId: id);
    }
    return confirmed;
  }

  int confirmedOffset(UploadTicket ticket) => _confirmed[ticket.product.id] ?? 0;

  List<Product> myProducts() => [for (final id in _mine) product(id)];

  // ---- activity log

  /// A stand-in for backend/config/platform/activity_log.yml: each event's group, level and message.
  static const _events = <String, (String, String, String)>{
    'listing_created': ('upload', 'info', 'Listing created; waiting for its video'),
    'upload_received': ('upload', 'info', 'Video received'),
    'transcode_submitted': ('video', 'info', 'Making the streaming versions (144p and up)'),
    'transcode_succeeded': ('video', 'info', 'Video is live'),
    'order_placed': ('order', 'info', 'Order placed'),
    'upload_too_long': ('upload', 'warning', 'Video is longer than the limit; not uploaded'),
    'upload_started': ('upload', 'info', 'Upload started'),
    'upload_interrupted': ('upload', 'warning', 'Connection dropped; the upload will resume'),
    'upload_resumed': ('upload', 'info', 'Upload resumed where the server had it'),
    'upload_finished': ('upload', 'info', 'Upload finished'),
    'upload_failed': ('upload', 'error', 'Upload failed'),
    'upload_cancelled': ('upload', 'info', 'Upload cancelled'),
  };

  final List<LogEntry> _logs = [];

  /// Adds an entry the way the API would (unknown events are refused, as the API does).
  LogEntry log(
    String event, {
    String? productId,
    String? orderId,
    List<LogDetail> details = const [],
    String source = 'api',
    DateTime? at,
  }) {
    final (group, level, message) = _events[event] ?? (throw StateError('unknown event $event'));
    _seq++;
    final entry = LogEntry(
      id: 'log_$_seq',
      event: event,
      productId: productId,
      orderId: orderId,
      details: details,
      level: level,
      group: group,
      source: source,
      message: message,
      at: at ?? DateTime.now(),
    );
    _logs.add(entry);
    return entry;
  }

  LogEntry report(LogEntryCreate body) =>
      log(body.event, productId: body.productId, orderId: body.orderId, details: body.details, source: 'app');

  /// Newest first; the cursor is the last id of the previous page (as for products).
  LogPage logs({String? group, String? level, String? productId, String? cursor, int? limit}) {
    final hits =
        _logs
            .where(
              (e) =>
                  (group == null || e.group == group) &&
                  (level == null || e.level == level) &&
                  (productId == null || e.productId == productId),
            )
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    var rest = hits;
    if (cursor != null && cursor.isNotEmpty) {
      final at = hits.indexWhere((e) => e.id == cursor);
      rest = at < 0 ? [] : hits.sublist(at + 1);
    }
    final size = limit ?? 30;
    final page = rest.take(size).toList();
    return LogPage(items: page, nextCursor: rest.length > size ? page.last.id : null);
  }

  // ---- helpers

  /// Processing turns ready once its time has passed (checked on read, so there are no timers).
  Product _advance(Product p) {
    final at = _readyAt[p.id];
    if (p.videoStatus == 'processing' && at != null && !DateTime.now().isBefore(at)) {
      final ready = _withStatus(p, 'ready', hlsUrl: 'mock://media/${p.id}/master.m3u8');
      _products[p.id] = ready;
      log('transcode_succeeded', productId: p.id);
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
