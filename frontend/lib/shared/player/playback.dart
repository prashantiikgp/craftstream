/// One HLS playback session, whatever plays it: hls.js on the web, ExoPlayer (video_player) on Android.
/// The player widget only talks to this, so tests swap in a fake through [playbackFactoryProvider]. After an
/// error the widget throws the session away and starts a new one.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/media/player_engine.dart';
import 'playback_factory.dart';

enum PlaybackPhase { loading, playing, paused, ended, error }

/// The rung on screen: picture height and the bitrate the playlist advertises for it.
class Rung {
  final int height;
  final int bitrateBps;
  const Rung({required this.height, required this.bitrateBps});

  @override
  bool operator ==(Object other) => other is Rung && other.height == height && other.bitrateBps == bitrateBps;
  @override
  int get hashCode => Object.hash(height, bitrateBps);
}

@immutable
class PlaybackState {
  final PlaybackPhase phase;

  /// Waiting for data (the first segment, or a stall). The widget shows a spinner after a short delay.
  final bool buffering;

  /// A frame has been decoded, so the poster can go.
  final bool firstFrame;
  final Duration position, duration;
  final Rung? rung;

  /// The player's own bandwidth estimate (web only; null when unknown).
  final int? estimateBps;

  const PlaybackState({
    this.phase = PlaybackPhase.loading,
    this.buffering = true,
    this.firstFrame = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.rung,
    this.estimateBps,
  });

  PlaybackState copyWith({
    PlaybackPhase? phase,
    bool? buffering,
    bool? firstFrame,
    Duration? position,
    Duration? duration,
    Rung? rung,
    int? estimateBps,
  }) =>
      PlaybackState(
        phase: phase ?? this.phase,
        buffering: buffering ?? this.buffering,
        firstFrame: firstFrame ?? this.firstFrame,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        rung: rung ?? this.rung,
        estimateBps: estimateBps ?? this.estimateBps,
      );
}

abstract class Playback {
  ValueListenable<PlaybackState> get state;

  /// Load the stream (starting on the lowest rung) and play it. Called once, after the buyer taps play.
  Future<void> start();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);

  /// The video surface.
  Widget view();
  void dispose();
}

typedef PlaybackFactory = Playback Function(Uri stream, PlayerEngine rules);

final playbackFactoryProvider = Provider<PlaybackFactory>((ref) => createPlayback);
