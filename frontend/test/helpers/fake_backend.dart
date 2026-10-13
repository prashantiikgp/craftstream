// An in-memory stand-in for the API and a GCS resumable-upload session, behind package:http's MockClient.
// It follows the real protocol (Content-Range PUTs, 308 + Range) and can drop the connection on chosen PUTs,
// after keeping part of the chunk the way GCS may.
import 'dart:convert';

import 'package:craftstream/data/generated/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const kib256 = 256 * 1024;

class FakeBackend {
  /// Index (0-based) of the session PUTs that fail mid-way.
  final Set<int> dropPuts;

  /// When a PUT drops, how many 256 KiB blocks of it the session still keeps.
  final int keptBlocksOnDrop;

  final int chunkSizeBytes;
  final int maxDurationSeconds;

  FakeBackend({this.dropPuts = const {}, this.keptBlocksOnDrop = 1, this.chunkSizeBytes = kib256, this.maxDurationSeconds = 900});

  static const uploadUrl = 'https://storage.test/upload/session-1';

  int received = 0;
  int puts = 0;
  int statusPolls = 0;
  final contentRanges = <String>[];
  final orders = <Map<String, dynamic>>[];
  Product? product;

  late final http.Client client = MockClient(_handle);

  Future<http.Response> _handle(http.Request r) async {
    final path = r.url.path;
    if (r.url.toString().startsWith(uploadUrl)) return _session(r);
    if (r.method == 'GET' && path == '/api/v1/upload-policy') {
      return _json(UploadPolicy(maxDurationSeconds: maxDurationSeconds,
          allowedMimeTypes: const ['video/mp4', 'video/quicktime'], chunkSizeBytes: chunkSizeBytes).toJson());
    }
    if (r.method == 'POST' && path == '/api/v1/products') {
      final body = ProductCreate.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
      product = Product(id: 'p_new', title: body.title, description: body.description, price: body.price,
          currency: body.currency, tags: body.tags, artisanName: body.artisanName, videoStatus: 'awaiting_upload',
          createdAt: DateTime(2026, 10, 13));
      return _json(UploadTicket(product: product!, uploadUrl: uploadUrl, uploadMethod: 'PUT',
          chunkSizeBytes: chunkSizeBytes).toJson(), 201);
    }
    if (r.method == 'GET' && path == '/api/v1/products/p_new') {
      statusPolls++;
      // Processing takes two polls after the upload completes.
      final p = product!;
      final status = p.videoStatus == 'processing' && statusPolls > 2 ? 'ready' : p.videoStatus;
      product = _withStatus(p, status, status == 'ready' ? 'https://media.test/p_new/master.m3u8' : null);
      return _json(product!.toJson());
    }
    if (r.method == 'POST' && path == '/api/v1/orders') {
      orders.add(jsonDecode(r.body) as Map<String, dynamic>);
      return _json({...orders.last, 'id': 'o_1', 'total': 1450.0, 'currency': 'INR', 'status': 'placed',
          'created_at': '2026-10-13T10:00:00Z'}, 201);
    }
    return http.Response('{"code":"not_found","message":"no route","details":[]}', 404);
  }

  Future<http.Response> _session(http.Request r) async {
    final range = r.headers['Content-Range'] ?? r.headers['content-range'] ?? '';
    contentRanges.add(range);
    final m = RegExp(r'^bytes (?:(\d+)-(\d+)|\*)/(\d+)$').firstMatch(range);
    if (m == null) return http.Response('bad range', 400);
    final total = int.parse(m.group(3)!);
    if (m.group(1) != null) {
      final start = int.parse(m.group(1)!), end = int.parse(m.group(2)!);
      if (r.bodyBytes.length != end - start + 1) return http.Response('length mismatch', 400);
      final index = puts++;
      if (start > received) return _progress(total); // a gap: ignore it, the client resumes from Range
      if (dropPuts.contains(index)) {
        received = start + (keptBlocksOnDrop * kib256).clamp(0, end - start + 1);
        throw http.ClientException('Connection closed while receiving data', r.url);
      }
      received = end + 1 > received ? end + 1 : received;
    }
    return _progress(total);
  }

  http.Response _progress(int total) {
    if (received >= total) {
      product = _withStatus(product!, 'processing', null);
      statusPolls = 0;
      return http.Response('{}', 200);
    }
    return http.Response('', 308, headers: {if (received > 0) 'range': 'bytes=0-${received - 1}'});
  }

  static Product _withStatus(Product p, String status, String? hls) => Product(id: p.id, title: p.title,
      description: p.description, price: p.price, currency: p.currency, tags: p.tags, artisanName: p.artisanName,
      videoStatus: status, hlsUrl: hls, createdAt: p.createdAt);

  static http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
}
