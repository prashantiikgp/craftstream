/// Android (and other dart:io platforms): file_picker gives a path; the length comes from video_player.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';

import '../../domain/media/upload_engine.dart';
import 'picked_video.dart';

Future<PickedVideo?> pickVideo(UploadEngine rules) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.video);
  final picked = result?.files.singleOrNull;
  final path = picked?.path;
  if (picked == null || path == null) return null;
  final file = File(path);
  return PickedVideo(
    name: picked.name,
    sizeBytes: await file.length(),
    mimeType: rules.mimeTypeFor(picked.extension),
    duration: await _durationOf(file, rules.metadataTimeout),
    read: (start, end) => file.openRead(start, end),
  );
}

/// Null when the video cannot be opened here; the server still caps processing at the limit.
Future<Duration?> _durationOf(File file, Duration timeout) async {
  final player = VideoPlayerController.file(file);
  try {
    await player.initialize().timeout(timeout);
    final d = player.value.duration;
    return d > Duration.zero ? d : null;
  } catch (_) {
    return null;
  } finally {
    await player.dispose();
  }
}
