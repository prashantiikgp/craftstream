/// A video the artisan picked, before upload. Device-side only: never sent to the API as-is.
library;

class PickedVideo {
  final String name;
  final int sizeBytes;
  final String mimeType;

  /// Null when the device could not read the length (the server still caps processing at the limit).
  final Duration? duration;

  /// Reads bytes [start, end) without loading the whole file. Null for mock videos.
  final Stream<List<int>> Function(int start, int end)? read;

  const PickedVideo({
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
    this.duration,
    this.read,
  });
}
