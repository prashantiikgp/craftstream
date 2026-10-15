/// The fake backend's timing and sample data from mock.yml (MOCK_DATA=true). Pure Dart: lib/data/mock/ turns the
/// fixtures into model objects and applies the delays.
library;

import '../../schemas/dev/mock_schema.dart';

class MockRulesError implements Exception {
  final String message;
  const MockRulesError(this.message);
  @override
  String toString() => 'mock.yml: $message';
}

const _idPlaceholder = '{id}';

class MockEngine {
  final MockSchema rules;

  MockEngine(this.rules) {
    if (rules.latencyMs < 0 || rules.chunkDelayMs < 0 || rules.processingSeconds < 0) {
      throw const MockRulesError('latency_ms, chunk_delay_ms and processing_seconds must be >= 0');
    }
    if (rules.pageSizes.products < 1 || rules.pageSizes.logs < 1) {
      throw const MockRulesError('page_sizes must be at least 1');
    }
    final policy = rules.uploadPolicy;
    if (policy.maxDurationSeconds < 1 || policy.chunkSizeBytes < 1 || policy.allowedMimeTypes.isEmpty) {
      throw const MockRulesError('upload_policy needs a duration, a chunk size and at least one type');
    }
    for (final (name, url) in [('hls_url', rules.hlsUrl), ('upload_url', rules.uploadUrl)]) {
      if (!url.contains(_idPlaceholder)) throw MockRulesError('$name must contain $_idPlaceholder');
    }
    if (rules.logEvents.isEmpty) throw const MockRulesError('log_events must not be empty');
    if (rules.videos.isEmpty) throw const MockRulesError('videos must not be empty');
    if (rules.products.isEmpty) throw const MockRulesError('products must not be empty');
    final ids = <String>{};
    for (final p in rules.products) {
      if (!ids.add(p.id)) throw MockRulesError('product id "${p.id}" is listed twice');
      if (DateTime.tryParse(p.createdAt) == null) {
        throw MockRulesError('${p.id}.created_at: "${p.createdAt}" is not a date-time');
      }
    }
  }

  Duration get latency => Duration(milliseconds: rules.latencyMs);
  Duration get chunkDelay => Duration(milliseconds: rules.chunkDelayMs);

  /// How long a finished upload stays processing.
  Duration get processingTime => Duration(seconds: rules.processingSeconds);

  /// This device's artisan (the upload form starts with this name).
  String get artisanName => rules.artisanName;

  List<MockProductSchema> get products => rules.products;

  /// The listings this device's artisan owns, in file order.
  List<String> get myProductIds => [
    for (final p in rules.products)
      if (p.mine) p.id,
  ];

  /// Every video status the fixtures use, for the startup cross-check against status.yml.
  Set<String> get statuses => {for (final p in rules.products) p.status};

  DateTime createdAt(MockProductSchema p) => DateTime.parse(p.createdAt);

  String hlsUrlFor(String productId) => rules.hlsUrl.replaceAll(_idPlaceholder, productId);
  String uploadUrlFor(String productId) => rules.uploadUrl.replaceAll(_idPlaceholder, productId);

  /// An activity-log event's group, level and message; null for an event the API would refuse.
  MockLogEventSchema? event(String name) => rules.logEvents[name];

  MockUploadPolicySchema get uploadPolicy => rules.uploadPolicy;
  String get currency => rules.currency;
  int get productPageSize => rules.pageSizes.products;
  int get logPageSize => rules.pageSizes.logs;

  /// "Pick a video" returns these in turn.
  List<MockVideoSchema> get videos => rules.videos;
  Duration videoLength(MockVideoSchema v) => Duration(seconds: v.seconds);
}
