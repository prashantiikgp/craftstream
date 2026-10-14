/// Android (and any non-web build): video_player, which is ExoPlayer on Android.
///
/// Starting low: video_player exposes none of ExoPlayer's track selection or bandwidth settings, and ExoPlayer
/// picks its first rung from its own bandwidth guess (several Mbps on Wi-Fi), not from playlist order. So the
/// session fetches the master playlist itself, hands ExoPlayer a `data:` copy that lists only the lowest rung
/// (`lowestRungOnly`), and swaps in the real master once the buffer proves the link is fast
/// (`PlayerEngine.shouldUpswitchNative`). On a slow link the swap never happens and playback stays on 144p.
///
/// The rung overlay: ExoPlayer reports only the picture size, so the bitrate is looked up by height in the
/// master playlist already fetched.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../domain/media/player_engine.dart';
import 'master_playlist.dart';
import 'playback.dart';

Playback createPlayback(Uri stream, PlayerEngine rules) => NativePlayback(stream, rules);

class NativePlayback implements Playback {
  final Uri stream;
  final PlayerEngine rules;
  final ValueNotifier<VideoPlayerController?> _ctrl = ValueNotifier(null);
  final _state = ValueNotifier(const PlaybackState());
  List<Variant> _variants = const [];
  bool _disposed = false;
  bool _fullLadder = false; // true once ExoPlayer has the real master (or the lowest-only copy was not needed)
  bool _switching = false;

  NativePlayback(this.stream, this.rules);

  @override
  ValueListenable<PlaybackState> get state => _state;

  VideoPlayerController? get _c => _ctrl.value;

  @override
  Future<void> start() async {
    final first = await _startUri();
    if (_disposed) return;
    final c = VideoPlayerController.networkUrl(first, formatHint: VideoFormat.hls);
    _ctrl.value = c;
    c.addListener(_onValue);
    try {
      await c.initialize();
      if (!_disposed) await c.play();
    } catch (_) {
      _set(_state.value.copyWith(phase: PlaybackPhase.error, buffering: false));
    }
  }

  /// The lowest-rung-only copy of the master playlist as a `data:` URI, or the stream itself when the master
  /// cannot be fetched or has a single rung (then ExoPlayer has nothing to get wrong).
  Future<Uri> _startUri() async {
    try {
      final res = await http.get(stream).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        _variants = parseMasterPlaylist(res.body);
        final lowest = lowestRungOnly(res.body, stream);
        if (lowest != null) {
          return Uri.dataFromString(lowest, mimeType: 'application/vnd.apple.mpegurl', encoding: utf8, base64: true);
        }
      }
    } catch (_) {
      // Fall through: the overlay then shows the height alone.
    }
    _fullLadder = true;
    return stream;
  }

  void _onValue() {
    final c = _c;
    if (c == null) return;
    final v = c.value;
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
    if (!_fullLadder && !_switching && v.isInitialized && v.isPlaying) {
      final ahead = bufferedAhead(v);
      if (rules.shouldUpswitchNative(bufferedAhead: ahead, position: v.position)) unawaited(_upswitch(c));
    }
  }

  /// How far the buffer reaches past the play position.
  static Duration bufferedAhead(VideoPlayerValue v) {
    var end = Duration.zero;
    for (final r in v.buffered) {
      if (r.end > end) end = r.end;
    }
    return end > v.position ? end - v.position : Duration.zero;
  }

  /// The link is fast: hand ExoPlayer the real master so it can climb the ladder. ExoPlayer's bandwidth meter is
  /// process-wide, so the new session already knows the measured throughput and picks a fitting rung. The old
  /// session keeps playing until the new one is ready; on any failure playback simply stays on the lowest rung.
  Future<void> _upswitch(VideoPlayerController old) async {
    _switching = true;
    final next = VideoPlayerController.networkUrl(stream, formatHint: VideoFormat.hls);
    try {
      await next.initialize();
      await next.seekTo(old.value.position);
      if (_disposed) {
        await next.dispose();
        return;
      }
      old.removeListener(_onValue);
      await old.pause();
      next.addListener(_onValue);
      _ctrl.value = next;
      await next.play();
      await old.dispose();
    } catch (_) {
      await next.dispose();
    } finally {
      _fullLadder = true;
      _switching = false;
    }
  }

  void _set(PlaybackState s) {
    if (!_disposed) _state.value = s;
  }

  @override
  Future<void> play() async {
    final c = _c;
    if (c == null) return;
    if (_state.value.phase == PlaybackPhase.ended) await c.seekTo(Duration.zero);
    await c.play();
  }

  @override
  Future<void> pause() async => _c?.pause();

  @override
  Future<void> seekTo(Duration position) async => _c?.seekTo(position);

  @override
  Widget view() => ValueListenableBuilder(
        valueListenable: _ctrl,
        builder: (_, c, _) => c == null
            ? const SizedBox.expand()
            : ValueListenableBuilder(
                valueListenable: c,
                builder: (_, v, _) => v.isInitialized
                    ? Center(child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(c)))
                    : const SizedBox.expand(),
              ),
      );

  @override
  void dispose() {
    _disposed = true;
    _c?.removeListener(_onValue);
    _c?.dispose();
    _ctrl.dispose();
    _state.dispose();
  }
}
