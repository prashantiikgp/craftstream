// GENERATED FROM models/ BY tools/codegen.py. DO NOT EDIT BY HAND.
// ignore_for_file: type=lint

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final int statusCode;
  final String body;
  /// Parsed error body, when the server sent the standard ErrorResponse shape.
  final ErrorResponse? error;
  ApiException(this.statusCode, this.body, this.error);
  @override
  String toString() => 'ApiException($statusCode): $body';
}

class ApiClient {
  final String baseUrl;
  final http.Client _http;

  ApiClient(String host, {http.Client? client})
      : baseUrl = '$host/api/v1',
        _http = client ?? http.Client();

  dynamic _decode(http.Response r) {
    final text = utf8.decode(r.bodyBytes);
    if (r.statusCode >= 400) {
      ErrorResponse? error;
      try {
        error = ErrorResponse.fromJson(jsonDecode(text) as Map<String, dynamic>);
      } catch (_) {}
      throw ApiException(r.statusCode, text, error);
    }
    return jsonDecode(text);
  }

  /// Create a listing and get a resumable upload URL for its video.
  Future<UploadTicket> createProduct(ProductCreate body) async {
    final uri = Uri.parse('$baseUrl/products');
    final r = await _http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body.toJson()));
    return UploadTicket.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// Search and filter products whose video is ready, one page at a time.
  Future<ProductPage> listProducts({String? q, String? tag, String? cursor, int? limit}) async {
    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: {if (q != null) 'q': q, if (tag != null) 'tag': tag, if (cursor != null) 'cursor': cursor, if (limit != null) 'limit': limit.toString()});
    final r = await _http.get(uri);
    return ProductPage.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// Product details with video status and HLS URL (poll this while the video processes).
  Future<Product> getProduct(String productId) async {
    final uri = Uri.parse('$baseUrl/products/$productId');
    final r = await _http.get(uri);
    return Product.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// Tags for the filter chips.
  Future<TagList> listTags() async {
    final uri = Uri.parse('$baseUrl/tags');
    final r = await _http.get(uri);
    return TagList.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// Limits to check on the device before uploading (15-min cap, file types, chunk size).
  Future<UploadPolicy> getUploadPolicy() async {
    final uri = Uri.parse('$baseUrl/upload-policy');
    final r = await _http.get(uri);
    return UploadPolicy.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// Place an order. The flow ends here.
  Future<Order> createOrder(OrderCreate body) async {
    final uri = Uri.parse('$baseUrl/orders');
    final r = await _http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body.toJson()));
    return Order.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// One order, so a device can show its orders after a restart (it keeps only their ids).
  Future<Order> getOrder(String orderId) async {
    final uri = Uri.parse('$baseUrl/orders/$orderId');
    final r = await _http.get(uri);
    return Order.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// The activity log, newest first, optionally narrowed to a group, level or listing.
  Future<LogPage> listLogs({String? group, String? level, String? productId, String? cursor, int? limit}) async {
    final uri = Uri.parse('$baseUrl/logs').replace(queryParameters: {if (group != null) 'group': group, if (level != null) 'level': level, if (productId != null) 'product_id': productId, if (cursor != null) 'cursor': cursor, if (limit != null) 'limit': limit.toString()});
    final r = await _http.get(uri);
    return LogPage.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// The app reports an upload step only it sees (started, network dropped, resumed, finished, failed).
  Future<LogEntry> createLog(LogEntryCreate body) async {
    final uri = Uri.parse('$baseUrl/logs');
    final r = await _http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body.toJson()));
    return LogEntry.fromJson(_decode(r) as Map<String, dynamic>);
  }

}
