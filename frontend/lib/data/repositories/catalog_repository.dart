/// Products for buyers: search, details and tags. Screens depend on the interface; the provider in
/// data/providers.dart picks the API or the mock (MOCK_DATA).
library;

import '../generated/api_client.dart';
import '../generated/models.dart';

abstract interface class CatalogRepository {
  /// Ready products matching the keyword and/or tag, one page at a time.
  Future<ProductPage> search({String? q, String? tag, String? cursor, int? limit});

  Future<Product> product(String id);

  /// Tags with at least one ready product, most used first.
  Future<List<String>> tags();
}

class ApiCatalogRepository implements CatalogRepository {
  final ApiClient _api;
  const ApiCatalogRepository(this._api);

  @override
  Future<ProductPage> search({String? q, String? tag, String? cursor, int? limit}) =>
      _api.listProducts(q: q, tag: tag, cursor: cursor, limit: limit);

  @override
  Future<Product> product(String id) => _api.getProduct(id);

  @override
  Future<List<String>> tags() async => (await _api.listTags()).tags;
}
