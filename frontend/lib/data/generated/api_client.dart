// GENERATED FROM models/ BY tools/codegen.py. DO NOT EDIT BY HAND.
// ignore_for_file: type=lint

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);
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
    if (r.statusCode >= 400) throw ApiException(r.statusCode, r.body);
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  /// Create a listing and get a resumable upload URL for its video.
  Future<UploadTicket> createProduct(ProductCreate body) async {
    final uri = Uri.parse('$baseUrl/products');
    final r = await _http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body.toJson()));
    return UploadTicket.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// Search and filter products (only ones whose video is ready).
  Future<List<Product>> listProducts({String? q, String? tag}) async {
    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: {if (q != null) 'q': q, if (tag != null) 'tag': tag});
    final r = await _http.get(uri);
    return (_decode(r) as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Product details, including the HLS playback URL.
  Future<Product> getProduct(String productId) async {
    final uri = Uri.parse('$baseUrl/products/$productId');
    final r = await _http.get(uri);
    return Product.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// Called by the app after the upload finishes; starts transcoding.
  Future<Product> markUploadComplete(String productId) async {
    final uri = Uri.parse('$baseUrl/products/$productId/upload-complete');
    final r = await _http.post(uri);
    return Product.fromJson(_decode(r) as Map<String, dynamic>);
  }

  /// Place an order. The flow ends here.
  Future<Order> createOrder(OrderCreate body) async {
    final uri = Uri.parse('$baseUrl/orders');
    final r = await _http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body.toJson()));
    return Order.fromJson(_decode(r) as Map<String, dynamic>);
  }

}
