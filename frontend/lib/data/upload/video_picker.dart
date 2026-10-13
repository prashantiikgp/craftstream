/// Picks the process video and reads what the upload check needs on the device: size, type and length.
/// Bytes are read later, one chunk at a time ([PickedVideo.read]), so a multi-GB video never sits in memory.
/// Web uses the browser's File (Blob.slice); Android uses the file path (File.openRead).
library;

import 'device_video_picker_io.dart' if (dart.library.js_interop) 'device_video_picker_web.dart' as device;
import 'picked_video.dart';

abstract interface class VideoPicker {
  /// Null when the artisan cancels.
  Future<PickedVideo?> pick();
}

class DeviceVideoPicker implements VideoPicker {
  const DeviceVideoPicker();

  @override
  Future<PickedVideo?> pick() => device.pickVideo();
}

/// Used when the device does not report a type. The server checks the type again.
String mimeOfExtension(String? ext) => switch (ext?.toLowerCase()) {
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'mkv' => 'video/x-matroska',
      '3gp' => 'video/3gpp',
      _ => 'video/mp4',
    };
