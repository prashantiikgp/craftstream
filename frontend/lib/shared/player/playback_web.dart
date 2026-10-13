/// Chrome: our own `<video>` + hls.js, so every start-low setting from player.yml reaches hls.js
/// (`startLevel: 0`, a 40 kbps first guess, capped buffer) and the overlay can show the real rung.
///
/// hls.js is bundled in web/vendor/ and loaded by web/index.html; it is never fetched from a CDN at runtime.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../domain/media/player_engine.dart';
import 'playback.dart';

Playback createPlayback(Uri stream, PlayerEngine rules) => WebPlayback(stream, rules);

@JS('Hls')
extension type _Hls._(JSObject _) implements JSObject {
  external _Hls(JSAny? config);
  external static bool isSupported();
  external void loadSource(String url);
  external void attachMedia(web.HTMLVideoElement media);
  external void startLoad();
  external void recoverMediaError();
  external void on(String event, JSFunction callback);
  external void destroy();
  external JSArray<_Level> get levels;
  external num get bandwidthEstimate;
}

extension type _Level._(JSObject _) implements JSObject {
  external int get bitrate;
  external int get height;
}

extension type _FragData._(JSObject _) implements JSObject {
  external _Frag get frag;
}

extension type _Frag._(JSObject _) implements JSObject {
  external int get level;
}

extension type _ErrorData._(JSObject _) implements JSObject {
  external bool get fatal;
  external String get type;
}

bool get _hlsLoaded => globalContext.has('Hls');

class WebPlayback implements Playback {
  final Uri stream;
  final PlayerEngine rules;
  final _state = ValueNotifier(const PlaybackState());
  web.HTMLVideoElement? _video;
  _Hls? _hls;
  bool _started = false, _loaded = false, _disposed = false, _mediaRecovered = false;

  WebPlayback(this.stream, this.rules);

  @override
  ValueListenable<PlaybackState> get state => _state;

  @override
  Future<void> start() async {
    _started = true;
    _load();
  }

  void _attach(Object element) {
    final v = element as web.HTMLVideoElement;
    _video = v
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..playsInline = true
      ..controls = false
      ..preload = 'none';
    void on(String type, void Function() f) => v.addEventListener(type, ((web.Event _) => f()).toJS);
    on('waiting', () => _set(_s.copyWith(buffering: true)));
    on('playing', () => _set(_s.copyWith(phase: PlaybackPhase.playing, buffering: false)));
    on('pause', () => _set(_s.copyWith(phase: v.ended ? PlaybackPhase.ended : PlaybackPhase.paused)));
    on('ended', () => _set(_s.copyWith(phase: PlaybackPhase.ended, buffering: false)));
    on('loadeddata', () => _set(_s.copyWith(firstFrame: true)));
    on('timeupdate', () => _set(_s.copyWith(position: _seconds(v.currentTime))));
    on('durationchange', () {
      if (v.duration.isFinite) _set(_s.copyWith(duration: _seconds(v.duration)));
    });
    on('error', () {
      if (_hls == null) _fail(); // with hls.js, its own error event decides
    });
    _load();
  }

  void _load() {
    final v = _video;
    if (!_started || v == null || _loaded || _disposed) return;
    _loaded = true;
    if (_hlsLoaded && _Hls.isSupported()) {
      final hls = _Hls(rules.hlsJsConfig().jsify());
      _hls = hls;
      hls.on('hlsManifestParsed', ((JSString _, JSObject _) => _play()).toJS);
      hls.on('hlsFragChanged', ((JSString _, _FragData d) => _showLevel(d.frag.level)).toJS);
      hls.on('hlsFragLoaded', ((JSString _, JSObject _) {
        final bps = hls.bandwidthEstimate;
        if (bps.isFinite && bps > 0) _set(_s.copyWith(estimateBps: bps.round()));
      }).toJS);
      hls.on('hlsError', ((JSString _, _ErrorData d) {
        if (!d.fatal) return;
        if (d.type == 'mediaError' && !_mediaRecovered) {
          _mediaRecovered = true;
          hls.recoverMediaError();
        } else {
          _fail();
        }
      }).toJS);
      hls.loadSource(stream.toString());
      hls.attachMedia(v);
    } else if (v.canPlayType('application/vnd.apple.mpegurl').isNotEmpty) {
      v.src = stream.toString(); // Safari plays HLS itself
      _play();
    } else {
      _fail();
    }
  }

  void _showLevel(int index) {
    final levels = _hls?.levels.toDart;
    if (levels == null || index < 0 || index >= levels.length) return;
    final l = levels[index];
    _set(_s.copyWith(rung: Rung(height: l.height, bitrateBps: l.bitrate)));
  }

  void _play() {
    final v = _video;
    if (v == null || _disposed) return;
    unawaited(v.play().toDart.then((_) {}, onError: (Object _) {
      // The browser refused to start playback (no user gesture yet): wait for the play button.
      _set(_s.copyWith(phase: PlaybackPhase.paused, buffering: false));
    }));
  }

  void _fail() => _set(_s.copyWith(phase: PlaybackPhase.error, buffering: false));

  PlaybackState get _s => _state.value;

  void _set(PlaybackState s) {
    if (!_disposed) _state.value = s;
  }

  static Duration _seconds(num s) => Duration(milliseconds: (s * 1000).round());

  @override
  Future<void> play() async {
    final v = _video;
    if (v == null) return;
    if (v.ended) v.currentTime = 0;
    _play();
  }

  @override
  Future<void> pause() async => _video?.pause();

  @override
  Future<void> seekTo(Duration position) async => _video?.currentTime = position.inMilliseconds / 1000;

  @override
  Widget view() => HtmlElementView.fromTagName(tagName: 'video', onElementCreated: _attach);

  @override
  void dispose() {
    _disposed = true;
    _hls?.destroy();
    _video
      ?..pause()
      ..removeAttribute('src')
      ..load();
    _state.dispose();
  }
}
