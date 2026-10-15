// The resumable uploader speaks the GCS protocol: ranged PUTs, 308 + Range, "bytes */total" to ask what arrived.
import 'dart:io';
import 'dart:typed_data';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/data/upload/resumable_uploader.dart';
import 'package:craftstream/domain/media/upload_engine.dart';
import 'package:craftstream/schemas/media/upload_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fake_backend.dart';

/// upload.yml says which answers mean done, continue, retry or reject.
final rules = UploadEngine(
  parseYaml(File('assets/config/media/upload.yml').readAsStringSync(), 'upload.yml', UploadSchema.fromJson),
);

void main() {
  final url = Uri.parse(FakeBackend.uploadUrl);

  test('reads the confirmed offset from the Range header', () {
    expect(ResumableUploader.receivedFrom(null), 0);
    expect(ResumableUploader.receivedFrom('bytes=0-262143'), 262144);
  });

  test('sends ranged chunks until the server says the file is complete', () async {
    final server = FakeBackend();
    final up = ResumableUploader(server.client, rules);
    const total = kib256 * 2 + 1000;
    // The fake marks the product as processing when done, so give it one.
    await server.client.post(
      Uri.parse('http://api.test/api/v1/products'),
      body: '{"title":"t","description":"d","price":1,"currency":"INR","tags":[],"artisan_name":"a"}',
    );

    expect(await up.sendChunk(url: url, bytes: Uint8List(kib256), start: 0, total: total), kib256);
    expect(await up.sendChunk(url: url, bytes: Uint8List(kib256), start: kib256, total: total), kib256 * 2);
    expect(await up.sendChunk(url: url, bytes: Uint8List(1000), start: kib256 * 2, total: total), total);
    expect(server.contentRanges, ['bytes 0-262143/525288', 'bytes 262144-524287/525288', 'bytes 524288-525287/525288']);
  });

  test('a dropped connection becomes UploadInterrupted, and the session reports what it kept', () async {
    final server = FakeBackend(dropPuts: {0}, keptBlocksOnDrop: 1);
    final up = ResumableUploader(server.client, rules);
    await server.client.post(
      Uri.parse('http://api.test/api/v1/products'),
      body: '{"title":"t","description":"d","price":1,"currency":"INR","tags":[],"artisan_name":"a"}',
    );

    await expectLater(
      up.sendChunk(url: url, bytes: Uint8List(kib256 * 2), start: 0, total: kib256 * 4),
      throwsA(isA<UploadInterrupted>()),
    );
    expect(await up.confirmedOffset(url: url, total: kib256 * 4), kib256);
    expect(server.contentRanges.last, 'bytes */1048576');
  });

  test('5xx and 429 are retryable; an expired session is not', () async {
    Future<Object?> outcome(int status) async {
      final up = ResumableUploader(MockClient((_) async => http.Response('', status)), rules);
      try {
        await up.confirmedOffset(url: url, total: 10);
        return null;
      } catch (e) {
        return e;
      }
    }

    expect(await outcome(503), isA<UploadInterrupted>());
    expect(await outcome(429), isA<UploadInterrupted>());
    expect(await outcome(410), isA<UploadRejected>());
    expect(await outcome(404), isA<UploadRejected>());
    expect(await outcome(201), isNull);
    expect(await outcome(408), isA<UploadInterrupted>());
    expect(await outcome(400), isA<UploadRejected>());
  });
}
