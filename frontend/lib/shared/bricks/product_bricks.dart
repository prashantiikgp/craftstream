/// Builders for the product-page bricks in bricks.yml: split, value, tag_row, artisan_row, notice, buy_bar and
/// video_player (the low-bandwidth process video; playback rules come from media/player.yml).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../domain/ui/bricks_engine.dart';
import '../format/bytes.dart';
import '../format/money.dart';
import '../player/playback.dart';
import '../screens/screen_scope.dart';
import '../theme/app_theme.dart';
import 'bricks.dart';
import 'kit.dart';

Widget _column(BuildContext context, List<BrickNode> nodes, double gap) {
  final scope = BrickScope.of(context);
  final shown = nodes.where(scope.shows).toList();
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
    for (final (i, n) in shown.indexed) ...[if (i > 0) SizedBox(height: gap), buildBrick(context, n)],
  ]);
}

Widget splitBrick(BuildContext context, BrickNode n) {
  final layout = configOf(context).layout;
  final width = MediaQuery.sizeOf(context).width;
  final gap = context.tokens.spacing(n.need('gap'));
  final first = _column(context, n.need('first'), gap), second = _column(context, n.need('second'), gap);
  if (!layout.productSideBySide(width)) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [first, SizedBox(height: gap), second]);
  }
  final f = layout.rules.sideBySideVideoFraction;
  final scale = BrickStyle.of(context, 'split').number('flex_scale');
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(flex: (f * scale).round(), child: first),
    SizedBox(width: context.tokens.spacing(n.need('side_gap'))),
    Expanded(flex: ((1 - f) * scale).round(), child: second),
  ]);
}

Widget valueBrick(BuildContext context, BrickNode n) {
  final v = BrickScope.of(context).lookup(n.need('bind'));
  return StyledText('${v ?? ''}', style: n.need('style'), color: context.tokens.color(n.need('color')));
}

Widget tagRowBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'tag_row');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final tags = scope.lookup(n.need('bind'));
  final accents = s.names('accents');
  return Wrap(spacing: s.space('gap'), runSpacing: s.space('gap'), children: [
    for (final (i, tag) in (tags is List ? tags : const []).indexed)
      scope.withItem(
        tag,
        i,
        Builder(builder: (context) {
          final accent = t.accent(accents[i % accents.length]);
          return Pressable(
            accent: accent.fill,
            semanticLabel: '$tag',
            onTap: () => BrickScope.of(context).act(context, n.prop<ActionSpec>('action')),
            builder: (context, active) => Container(
              height: s.number('height'),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: s.space('padding')),
              decoration: BoxDecoration(
                color: active ? accent.wash : s.color('background'),
                border: Border.all(color: accent.line),
              ),
              child: StyledText('$tag', style: s.name('label'), color: accent.ink),
            ),
          );
        }),
      ),
  ]);
}

Widget artisanRowBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'artisan_row');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final name = '${scope.lookup(n.need('name')) ?? ''}';
  final initials = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(s.number('initials').toInt()).map((w) => w[0]).join();
  final price = formatMoney(scope.lookup(n.need('price')) as num? ?? 0, '${scope.lookup(n.need('currency'))}');
  final avatar = t.accent(s.name('avatar_accent'));
  return Container(
    padding: EdgeInsets.symmetric(vertical: s.space('padding')),
    decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: s.color('border')))),
    child: Row(children: [
      Container(
        width: s.number('avatar'),
        height: s.number('avatar'),
        alignment: Alignment.center,
        color: avatar.fill,
        child: StyledText(initials.toUpperCase(), style: s.name('avatar_style'), color: avatar.onFill),
      ),
      SizedBox(width: s.space('gap')),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StyledText(name, style: s.name('name_style'), maxLines: 1),
          StyledText(say(context, n.need('caption')), style: s.name('caption_style'), color: s.color('caption_color')),
        ]),
      ),
      StyledText(price, style: s.name('price_style'), color: s.color('price_color')),
    ]),
  );
}

Widget noticeBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'notice');
  final t = context.tokens;
  final tone = t.tone(n.need('tone'));
  final message = n.prop<String>('message');
  return Container(
    padding: EdgeInsets.all(s.space('padding')),
    decoration: BoxDecoration(color: tone.wash, border: Border.all(color: tone.line)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      YamlIcon(n.need('icon'), size: s.number('icon'), color: tone.ink),
      SizedBox(width: s.space('gap')),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StyledText(say(context, n.need('title')), style: s.name('title'), color: tone.ink),
          if (message != null) ...[
            SizedBox(height: s.space('gap')),
            StyledText(say(context, message, args: n.prop('args')), style: s.name('message'), color: t.text),
          ],
        ]),
      ),
    ]),
  );
}

Widget buyBarBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'buy_bar');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final enabled = truthy(scope.lookup(n.need('enabled')));
  final tone = t.tone(enabled ? n.need('tone') : 'neutral');
  final price = formatMoney(scope.lookup(n.need('price')) as num? ?? 0, '${scope.lookup(n.need('currency'))}');
  final label = say(context, n.need('label'));
  return Row(children: [
    Expanded(child: StyledText(price, style: s.name('price'), color: s.color('price_color'))),
    SizedBox(width: s.space('gap')),
    SizedBox(
      width: s.number('button_width'),
      child: Pressable(
        accent: tone.fill,
        semanticLabel: label,
        onTap: enabled ? () => scope.act(context, n.prop<ActionSpec>('action')) : null,
        builder: (context, _) => Container(
          height: s.number('height'),
          alignment: Alignment.center,
          color: tone.fill,
          child: StyledText(label, style: s.name('label'), color: tone.onFill),
        ),
      ),
    ),
  ]);
}

Widget videoPlayerBrick(BuildContext context, BrickNode n) {
  final p = BrickScope.of(context).lookup(n.need('bind'));
  return p is Map ? _ProcessVideo(n, p) : const SizedBox.shrink();
}

/// The process video, built for slow connections (player.yml): nothing loads until the buyer taps play; the
/// poster stays until the first frame, with a spinner if the first segment is slow; playback starts on the
/// lowest rung and a pill shows the rung ("144p · 47 kbps").
class _ProcessVideo extends ConsumerStatefulWidget {
  final BrickNode n;
  final Map product;
  const _ProcessVideo(this.n, this.product);

  @override
  ConsumerState<_ProcessVideo> createState() => _ProcessVideoState();
}

class _ProcessVideoState extends ConsumerState<_ProcessVideo> {
  Playback? _playback;
  Timer? _spinnerDelay;
  bool _showSpinner = false;

  String get _hls => '${widget.product['hls_url']}';

  void _start() {
    final config = ref.read(appConfigProvider);
    final playback = ref.read(playbackFactoryProvider)(config.player.streamUri(_hls), config.player);
    playback.state.addListener(_onState);
    setState(() => _playback = playback);
    _onState();
    unawaited(playback.start());
  }

  /// After an error: a fresh session. The old one is disposed after the frame that drops its view.
  void _restart() {
    final old = _playback;
    _stop(dispose: false);
    _start();
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _stop({bool dispose = true}) {
    _spinnerDelay?.cancel();
    _playback?.state.removeListener(_onState);
    if (dispose) _playback?.dispose();
    _playback = null;
    _showSpinner = false;
  }

  /// Buffering shows a spinner only after a short delay, so quick waits do not flicker.
  void _onState() {
    final buffering = _playback?.state.value.buffering ?? false;
    if (!buffering) {
      _spinnerDelay?.cancel();
      if (_showSpinner) setState(() => _showSpinner = false);
    } else if (!_showSpinner && !(_spinnerDelay?.isActive ?? false)) {
      _spinnerDelay = Timer(ref.read(appConfigProvider).player.bufferingIndicatorDelay, () {
        if (mounted && (_playback?.state.value.buffering ?? false)) setState(() => _showSpinner = true);
      });
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = BrickStyle.of(context, 'video_player');
    final n = widget.n;
    final p = widget.product;
    final playback = _playback;
    final canPlay = truthy(p['ready']) && p['hls_url'] != null;
    final poster = Poster(seed: '${p['id']}', thumbnailUrl: p['thumbnail_url'] as String?);
    return AspectRatio(
      aspectRatio: s.number('aspect_w') / s.number('aspect_h'),
      child: ColoredBox(
        color: s.color('background'),
        child: playback == null
            ? Stack(fit: StackFit.expand, children: [
                poster,
                if (canPlay) Center(child: _BigButton(n, s, playing: false, onTap: _start)),
                Positioned(
                  left: s.space('inset'),
                  top: s.space('inset'),
                  right: s.space('inset'),
                  child: Align(alignment: Alignment.centerLeft, child: _Pill(s, say(context, n.need('slow_note')))),
                ),
              ])
            : ValueListenableBuilder(
                valueListenable: playback.state,
                builder: (context, st, _) => _playing(context, s, playback, st, poster),
              ),
      ),
    );
  }

  Widget _playing(BuildContext context, BrickStyle s, Playback playback, PlaybackState st, Widget poster) {
    final n = widget.n;
    final config = ref.watch(appConfigProvider);
    final rules = config.player;
    final strings = config.strings;
    final failed = st.phase == PlaybackPhase.error;
    final playing = st.phase == PlaybackPhase.playing;
    final rung = st.rung;
    final label = rung == null ? null : rules.rungLabel(height: rung.height, bitrateBps: rung.bitrateBps);
    final rungText = rung == null
        ? say(context, n.need('slow_note'))
        : rung.bitrateBps > 0
            ? strings.get(n.need('rung'), {'height': label!.height, 'kbps': label.kbps})
            : strings.get(n.need('rung_height_only'), {'height': rung.height});
    final estimate = st.estimateBps;
    return Stack(fit: StackFit.expand, children: [
      playback.view(),
      if (!st.firstFrame && rules.showPosterUntilFirstFrame && !failed) IgnorePointer(child: poster),
      // Tap the picture to play or pause.
      if (!failed)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => playing ? playback.pause() : playback.play(),
          ),
        ),
      if (_showSpinner && !failed)
        Center(
          child: Semantics(
            label: say(context, n.need('buffering')),
            child: SizedBox.square(
              dimension: s.number('spinner'),
              child: CircularProgressIndicator(strokeWidth: s.number('spinner_stroke'), color: s.color('accent')),
            ),
          ),
        ),
      if (!playing && !_showSpinner && !failed && st.firstFrame)
        Center(child: _BigButton(n, s, playing: false, onTap: playback.play)),
      if (failed)
        // Scales down rather than overflow on a small phone's 16:9 box.
        Padding(
          padding: EdgeInsets.all(s.space('inset')),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: s.number('error_max_width')),
              child: Container(
                padding: EdgeInsets.all(s.space('error_padding')),
                color: s.color('panel'),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  StyledText(say(context, n.need('error')), style: s.name('error_style'), align: TextAlign.center),
                  SizedBox(height: s.space('inset')),
                  Pressable(
                    accent: s.color('accent'),
                    semanticLabel: say(context, n.need('retry')),
                    onTap: _restart,
                    builder: (context, _) => Container(
                      padding: EdgeInsets.symmetric(horizontal: s.space('error_padding'), vertical: s.space('inset')),
                      color: s.color('accent'),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        YamlIcon(s.name('retry_icon'), size: s.number('pill_icon'), color: s.color('on_accent')),
                        SizedBox(width: s.space('pill_gap')),
                        StyledText(say(context, n.need('retry')), style: s.name('pill_style'), color: s.color('on_accent')),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      if (!failed)
        Positioned(
          left: s.space('inset'),
          top: s.space('inset'),
          right: s.space('inset'),
          child: Wrap(spacing: s.space('pill_gap'), runSpacing: s.space('pill_gap'), children: [
            _Pill(s, rungText),
            if (config.env.devTools && estimate != null)
              _Pill(s, strings.get(n.need('estimate'), {'kbps': (estimate / 1000).round()}), icon: s.name('estimate_icon')),
          ]),
        ),
      if (!failed && st.firstFrame)
        Positioned(left: 0, right: 0, bottom: 0, child: _Controls(n, s, playback, st)),
    ]);
  }
}

class _Controls extends StatelessWidget {
  final BrickNode n;
  final BrickStyle s;
  final Playback playback;
  final PlaybackState state;
  const _Controls(this.n, this.s, this.playback, this.state);

  @override
  Widget build(BuildContext context) {
    final playing = state.phase == PlaybackPhase.playing;
    final total = state.duration.inMilliseconds;
    final at = state.position.inMilliseconds.clamp(0, total > 0 ? total : 0);
    final strings = configOf(context).strings;
    final label = say(context, n.need(playing ? 'pause' : 'play'));
    return Container(
      color: s.color('bar'),
      padding: EdgeInsets.only(right: s.space('inset')),
      child: Row(children: [
        Tooltip(
          message: label,
          child: Pressable(
            accent: s.color('accent'),
            semanticLabel: label,
            onTap: playing ? playback.pause : playback.play,
            builder: (context, _) => SizedBox.square(
              dimension: s.number('control_box'),
              child: Center(
                child: YamlIcon(s.name(playing ? 'pause_icon' : 'play_icon'), size: s.number('control_icon'), color: s.color('on_bar')),
              ),
            ),
          ),
        ),
        Expanded(
          child: Semantics(
            label: say(context, n.need('seek')),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: s.number('track'),
                activeTrackColor: s.color('accent'),
                inactiveTrackColor: s.color('track_color'),
                thumbColor: s.color('accent'),
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: s.number('thumb')),
              ),
              child: Slider(
                value: total > 0 ? at / total : 0,
                onChanged: total > 0 ? (v) => playback.seekTo(Duration(milliseconds: (v * total).round())) : null,
              ),
            ),
          ),
        ),
        SizedBox(width: s.space('pill_gap')),
        StyledText(
          strings.get(n.need('time'), {'position': formatDuration(state.position), 'duration': formatDuration(state.duration)}),
          style: s.name('time_style'),
          color: s.color('on_bar'),
        ),
      ]),
    );
  }
}

class _BigButton extends StatelessWidget {
  final BrickNode n;
  final BrickStyle s;
  final bool playing;
  final VoidCallback onTap;
  const _BigButton(this.n, this.s, {required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        accent: s.color('accent'),
        semanticLabel: say(context, n.need('play')),
        onTap: onTap,
        builder: (context, _) => Container(
          width: s.number('play_box'),
          height: s.number('play_box'),
          alignment: Alignment.center,
          color: s.color('accent'),
          child: YamlIcon(s.name('play_icon'), size: s.number('play_icon_size'), color: s.color('on_accent')),
        ),
      );
}

class _Pill extends StatelessWidget {
  final BrickStyle s;
  final String text;
  final String? icon;
  const _Pill(this.s, this.text, {this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: s.space('pill_padding'), vertical: s.space('pill_gap')),
        color: s.color('bar'),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          YamlIcon(icon ?? s.name('pill_icon_name'), size: s.number('pill_icon'), color: s.color('pill_icon_color')),
          SizedBox(width: s.space('pill_gap')),
          Flexible(child: StyledText(text, style: s.name('pill_style'), color: s.color('on_bar'), maxLines: 1)),
        ]),
      );
}
