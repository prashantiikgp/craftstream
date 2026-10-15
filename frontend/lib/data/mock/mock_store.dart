/// In-app fake backend for MOCK_DATA=true: believable products, the same search rules as the API
/// (ready products only, every word must match, tag filter), orders and a simulated resumable upload.
/// Small delays make loading states visible. It keeps an activity log the way the API does (a few entries
/// for the sample products, then one per step). Timing, sample products and the stand-ins for the API's
/// policy and event catalogue come from dev/mock.yml (MockEngine). Nothing here is used when MOCK_DATA=false.
library;

import '../../domain/dev/mock_engine.dart';
import '../../schemas/dev/mock_schema.dart';
import '../generated/models.dart';
import '../upload/picked_video.dart';

class MockNotFound implements Exception {
  final String id;
  const MockNotFound(this.id);
  @override
  String toString() => 'No product $id';
}

class MockStore {
  final MockEngine rules;
  final Duration latency;
  final Duration chunkDelay;

  /// How long a finished upload stays "processing" before it turns ready.
  final Duration processingTime;

  final Map<String, Product> _products = {};
  final List<String> _mine;
  final Map<String, int> _confirmed = {};
  final Map<String, DateTime> _readyAt = {};
  int _seq = 0;

  /// Delays default to mock.yml's; tests pass zero.
  MockStore(this.rules, {Duration? latency, Duration? chunkDelay, Duration? processingTime})
    : latency = latency ?? rules.latency,
      chunkDelay = chunkDelay ?? rules.chunkDelay,
      processingTime = processingTime ?? rules.processingTime,
      _mine = rules.myProductIds {
    for (final fixture in rules.products) {
      final p = _productOf(fixture);
      _products[p.id] = p;
      log('listing_created', productId: p.id, at: p.createdAt);
      if (p.videoStatus == 'ready') {
        log('transcode_succeeded', productId: p.id, at: p.createdAt.add(this.processingTime));
      }
    }
  }

  /// A sample listing from mock.yml as the API would return it.
  Product _productOf(MockProductSchema p) => Product(
    id: p.id,
    title: p.title,
    description: p.description,
    price: p.price,
    currency: rules.currency,
    tags: p.tags,
    artisanName: p.artisan,
    videoStatus: p.status,
    hlsUrl: p.status == 'ready' ? rules.hlsUrlFor(p.id) : null,
    createdAt: rules.createdAt(p),
  );

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
    final size = limit ?? rules.productPageSize;
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

  UploadPolicy get policy => UploadPolicy(
    maxDurationSeconds: rules.uploadPolicy.maxDurationSeconds,
    allowedMimeTypes: rules.uploadPolicy.allowedMimeTypes,
    chunkSizeBytes: rules.uploadPolicy.chunkSizeBytes,
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
      uploadUrl: rules.uploadUrlFor(p.id),
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
    // mock.yml log_events: a stand-in for backend/config/platform/activity_log.yml.
    final e = rules.event(event) ?? (throw StateError('unknown event $event'));
    _seq++;
    final entry = LogEntry(
      id: 'log_$_seq',
      event: event,
      productId: productId,
      orderId: orderId,
      details: details,
      level: e.level,
      group: e.group,
      source: source,
      message: e.message,
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
    final size = limit ?? rules.logPageSize;
    final page = rest.take(size).toList();
    return LogPage(items: page, nextCursor: rest.length > size ? page.last.id : null);
  }

  // ---- helpers

  /// Processing turns ready once its time has passed (checked on read, so there are no timers).
  Product _advance(Product p) {
    final at = _readyAt[p.id];
    if (p.videoStatus == 'processing' && at != null && !DateTime.now().isBefore(at)) {
      final ready = _withStatus(p, 'ready', hlsUrl: rules.hlsUrlFor(p.id));
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
