/// The artisan side: upload policy, creating a listing, sending the video in resumable chunks and
/// following its processing. Mirrors the GCS resumable protocol: send a chunk, the server confirms an
/// offset; after a drop, ask for the confirmed offset and continue from there.
library;

import 'dart:typed_data';

import '../generated/api_client.dart';
import '../generated/models.dart';
import '../upload/picked_video.dart';
import '../upload/resumable_uploader.dart';

export '../upload/resumable_uploader.dart' show UploadInterrupted, UploadRejected;

abstract interface class UploadRepository {
  Future<UploadPolicy> policy();

  /// Creates the listing (video_status = awaiting_upload) and returns where to upload.
  Future<UploadTicket> createListing(ProductCreate body);

  /// Sends bytes [offset, offset + length) and returns the offset the server has confirmed.
  Future<int> sendChunk(UploadTicket ticket, PickedVideo video, int offset, int length);

  /// After an interruption: how many bytes the server already has.
  Future<int> confirmedOffset(UploadTicket ticket, PickedVideo video);

  /// Latest state of one listing (poll this while the video processes).
  Future<Product> status(String productId);

  /// Listings created from this device. There is no login, so "mine" is what this device created.
  Future<List<Product>> myProducts();
}

class ApiUploadRepository implements UploadRepository {
  final ApiClient _api;
  final ResumableUploader _uploader;
  final List<String> _mine = [];
  ApiUploadRepository(this._api, this._uploader);

  @override
  Future<UploadPolicy> policy() => _api.getUploadPolicy();

  @override
  Future<UploadTicket> createListing(ProductCreate body) async {
    final ticket = await _api.createProduct(body);
    _mine.insert(0, ticket.product.id);
    return ticket;
  }

  /// Reads only this chunk from the file (never the whole video) and PUTs it to the session URL.
  @override
  Future<int> sendChunk(UploadTicket ticket, PickedVideo video, int offset, int length) async {
    final read = video.read;
    if (read == null) throw StateError('${video.name} cannot be read from this device');
    final bytes = BytesBuilder(copy: false);
    await for (final part in read(offset, offset + length)) {
      bytes.add(part);
    }
    return _uploader.sendChunk(
        url: Uri.parse(ticket.uploadUrl), bytes: bytes.takeBytes(), start: offset, total: video.sizeBytes);
  }

  @override
  Future<int> confirmedOffset(UploadTicket ticket, PickedVideo video) =>
      _uploader.confirmedOffset(url: Uri.parse(ticket.uploadUrl), total: video.sizeBytes);

  @override
  Future<Product> status(String productId) => _api.getProduct(productId);

  @override
  Future<List<Product>> myProducts() => Future.wait([for (final id in _mine) _api.getProduct(id)]);
}
