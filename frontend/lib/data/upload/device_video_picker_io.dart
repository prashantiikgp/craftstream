/// Android (and other dart:io platforms): file_picker gives a path; the length comes from video_player.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';

import 'picked_video.dart';
import 'video_picker.dart';

Future<PickedVideo?> pickVideo() async {
  final result = await FilePicker.platform.pickFiles(type: FileType.video);
  final picked = result?.files.singleOrNull;
  final path = picked?.path;
  if (picked == null || path == null) return null;
  final file = File(path);
  return PickedVideo(
    name: picked.name,
    sizeBytes: await file.length(),
    mimeType: mimeOfExtension(picked.extension),
    duration: await _durationOf(file),
    read: (start, end) => file.openRead(start, end),
  );
}

/// Null when the video cannot be opened here; the server still caps processing at the limit.
Future<Duration?> _durationOf(File file) async {
  final player = VideoPlayerController.file(file);
  try {
    await player.initialize().timeout(const Duration(seconds: 15));
    final d = player.value.duration;
    return d > Duration.zero ? d : null;
  } catch (_) {
    return null;
  } finally {
    await player.dispose();
  }
}
