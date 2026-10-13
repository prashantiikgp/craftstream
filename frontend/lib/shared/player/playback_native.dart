/// Android (and any non-web build): video_player, which is ExoPlayer on Android.
///
/// Starting low: video_player has no API for ExoPlayer's track selection, so the initial bitrate cannot be
/// capped from Dart. ExoPlayer loads the first variant of the master playlist first, and our ladder lists the
/// lowest rung first (backend ladder_engine), so playback starts on it. ExoPlayer then only steps up once it
/// has 10 s buffered, which a sub-50 kbps link never builds.
///
/// The rung overlay: ExoPlayer reports only the picture size, so we fetch the master playlist (a few hundred
/// bytes) and look the bitrate up by height.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../domain/media/player_engine.dart';
import 'master_playlist.dart';
import 'playback.dart';

Playback createPlayback(Uri stream, PlayerEngine rules) => NativePlayback(stream);

class NativePlayback implements Playback {
  final Uri stream;
  final VideoPlayerController _c;
  final _state = ValueNotifier(const PlaybackState());
  List<Variant> _variants = const [];
  bool _disposed = false;

  NativePlayback(this.stream)
      : _c = VideoPlayerController.networkUrl(stream, formatHint: VideoFormat.hls);

  @override
  ValueListenable<PlaybackState> get state => _state;

  @override
  Future<void> start() async {
    unawaited(_loadVariants());
    _c.addListener(_onValue);
    try {
      await _c.initialize();
      if (!_disposed) await _c.play();
    } catch (_) {
      _set(_state.value.copyWith(phase: PlaybackPhase.error, buffering: false));
    }
  }

  Future<void> _loadVariants() async {
    try {
      final res = await http.get(stream).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) _variants = parseMasterPlaylist(res.body);
    } catch (_) {
      // The overlay then shows the height alone.
    }
  }

  void _onValue() {
    final v = _c.value;
    if (v.hasError) {
      _set(_state.value.copyWith(phase: PlaybackPhase.error, buffering: false));
      return;
    }
    final ended = v.isInitialized && v.duration > Duration.zero && v.position >= v.duration && !v.isPlaying;
    final height = v.size.height.round();
    final variant = height > 0 ? variantForHeight(_variants, height) : null;
    _set(_state.value.copyWith(
      phase: ended
          ? PlaybackPhase.ended
          : v.isPlaying
              ? PlaybackPhase.playing
              : v.isInitialized
                  ? PlaybackPhase.paused
                  : PlaybackPhase.loading,
      buffering: v.isBuffering || !v.isInitialized,
      firstFrame: v.isInitialized && (v.position > Duration.zero || v.isPlaying && !v.isBuffering),
      position: v.position,
      duration: v.duration,
      rung: height > 0 ? Rung(height: variant?.height ?? height, bitrateBps: variant?.bandwidthBps ?? 0) : null,
    ));
  }

  void _set(PlaybackState s) {
    if (!_disposed) _state.value = s;
  }

  @override
  Future<void> play() async {
    if (_state.value.phase == PlaybackPhase.ended) await _c.seekTo(Duration.zero);
    await _c.play();
  }

  @override
  Future<void> pause() => _c.pause();

  @override
  Future<void> seekTo(Duration position) => _c.seekTo(position);

  @override
  Widget view() => ValueListenableBuilder(
        valueListenable: _c,
        builder: (_, v, _) => v.isInitialized
            ? Center(child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(_c)))
            : const SizedBox.expand(),
      );

  @override
  void dispose() {
    _disposed = true;
    _c.removeListener(_onValue);
    _c.dispose();
    _state.dispose();
  }
}
