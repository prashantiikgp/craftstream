/// Picks the process video and reads what the upload check needs on the device: size, type and length.
/// Bytes are read later, one chunk at a time ([PickedVideo.read]), so a multi-GB video never sits in memory.
/// Web uses the browser's File (Blob.slice); Android uses the file path (File.openRead).
library;

import '../../domain/media/upload_engine.dart';
import 'device_video_picker_io.dart' if (dart.library.js_interop) 'device_video_picker_web.dart' as device;
import 'picked_video.dart';

abstract interface class VideoPicker {
  /// Null when the artisan cancels.
  Future<PickedVideo?> pick();
}

/// File types, the dialog's filter and the metadata timeout come from upload.yml ([UploadEngine]).
class DeviceVideoPicker implements VideoPicker {
  final UploadEngine rules;
  const DeviceVideoPicker(this.rules);

  @override
  Future<PickedVideo?> pick() => device.pickVideo(rules);
}
