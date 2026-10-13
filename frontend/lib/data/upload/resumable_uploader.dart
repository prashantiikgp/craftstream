/// Sends a video to a Cloud Storage resumable-upload session (or the local fake that speaks the same protocol):
///
///   PUT  Content-Range: bytes <start>-<end>/<total>  + the bytes  -> 308 + `Range: bytes=0-<last>` (more to send)
///                                                                  -> 200/201 (the whole file has arrived)
///   PUT  Content-Range: bytes */<total>, empty body                -> the same answers: "how much do you have?"
///
/// The caller decides what to send next from the offset each call returns. A dropped connection or a 5xx
/// throws [UploadInterrupted]: back off, ask [confirmedOffset], continue from there. Pure HTTP, no UI.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The connection dropped or the server hiccupped mid-chunk. Resume from [ResumableUploader.confirmedOffset].
class UploadInterrupted implements Exception {
  const UploadInterrupted();
  @override
  String toString() => 'UploadInterrupted';
}

/// The session refused the upload for good (expired, deleted, bad request). Start a new listing.
class UploadRejected implements Exception {
  final int statusCode;
  const UploadRejected(this.statusCode);
  @override
  String toString() => 'UploadRejected($statusCode)';
}

class ResumableUploader {
  final http.Client _http;
  const ResumableUploader(this._http);

  /// Sends [bytes] as the range starting at [start] of a [total]-byte file. Returns how many bytes the
  /// server now has (contiguous from 0); [total] means the upload is complete.
  Future<int> sendChunk({required Uri url, required Uint8List bytes, required int start, required int total}) {
    final end = start + bytes.length - 1;
    return _put(url, 'bytes $start-$end/$total', bytes, total);
  }

  /// After an interruption: how many bytes the server already has.
  Future<int> confirmedOffset({required Uri url, required int total}) =>
      _put(url, 'bytes */$total', Uint8List(0), total);

  Future<int> _put(Uri url, String contentRange, Uint8List body, int total) async {
    // A Request with a Uint8List body is sent as is. `http.put(body: bytes)` would copy an 8 MiB chunk
    // element by element (body.cast<int>()), which freezes the page on web.
    final request = http.Request('PUT', url)
      ..headers['Content-Range'] = contentRange
      ..bodyBytes = body;
    final http.Response r;
    try {
      r = await http.Response.fromStream(await _http.send(request));
    } on http.ClientException {
      throw const UploadInterrupted();
    } on TimeoutException {
      throw const UploadInterrupted();
    }
    return switch (r.statusCode) {
      200 || 201 => total,
      308 => receivedFrom(r.headers['range']),
      408 || 429 || >= 500 => throw const UploadInterrupted(),
      _ => throw UploadRejected(r.statusCode),
    };
  }

  /// `Range: bytes=0-<last>` → last + 1. No header means nothing has arrived yet.
  static int receivedFrom(String? range) {
    final m = RegExp(r'bytes=0-(\d+)').firstMatch(range ?? '');
    return m == null ? 0 : int.parse(m.group(1)!) + 1;
  }
}
