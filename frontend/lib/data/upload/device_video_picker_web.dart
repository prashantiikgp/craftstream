/// Chrome: a plain file input gives the browser's File. Its length comes from a <video> element reading only
/// the metadata of a blob URL, and chunks come from Blob.slice, so the file is never loaded whole.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../domain/media/upload_engine.dart';
import 'picked_video.dart';

Future<PickedVideo?> pickVideo(UploadEngine rules) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = rules.pickerAccept;
  final chosen = Completer<web.File?>();
  void settle(web.File? f) => chosen.isCompleted ? null : chosen.complete(f);
  input.addEventListener('change', ((web.Event _) => settle(input.files?.item(0))).toJS);
  input.addEventListener('cancel', ((web.Event _) => settle(null)).toJS);
  input.click(); // still inside the tap that called pick(), so the browser allows it

  final file = await chosen.future;
  if (file == null) return null;
  final ext = file.name.contains('.') ? file.name.split('.').last : null;
  return PickedVideo(
    name: file.name,
    sizeBytes: file.size,
    mimeType: file.type.isNotEmpty ? file.type : rules.mimeTypeFor(ext),
    duration: await _durationOf(file, rules.metadataTimeout),
    read: (start, end) =>
        Stream.fromFuture(file.slice(start, end).arrayBuffer().toDart.then((buffer) => buffer.toDart.asUint8List())),
  );
}

/// Null when the browser cannot decode the container (e.g. some .mkv); the server still caps the length.
Future<Duration?> _durationOf(web.File file, Duration timeout) async {
  final url = web.URL.createObjectURL(file);
  final video = web.HTMLVideoElement()
    ..preload = 'metadata'
    ..muted = true;
  final result = Completer<Duration?>();
  void settle(Duration? d) => result.isCompleted ? null : result.complete(d);
  video.addEventListener(
    'loadedmetadata',
    ((web.Event _) {
      final s = video.duration;
      settle(s.isFinite && s > 0 ? Duration(milliseconds: (s * 1000).round()) : null);
    }).toJS,
  );
  video.addEventListener('error', ((web.Event _) => settle(null)).toJS);
  video.src = url;
  try {
    return await result.future.timeout(timeout, onTimeout: () => null);
  } finally {
    video.removeAttribute('src');
    web.URL.revokeObjectURL(url);
  }
}
