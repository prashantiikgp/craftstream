// hls.js in browsers, video_player (ExoPlayer) everywhere else.
export 'playback_native.dart' if (dart.library.js_interop) 'playback_web.dart';
