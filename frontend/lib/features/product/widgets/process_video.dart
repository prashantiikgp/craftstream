import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../data/generated/models.dart';
import '../../../shared/player/playback.dart';
import '../../../shared/widgets/ds.dart';

/// The process video, built for slow connections (player.yml):
/// - nothing loads until the buyer taps play (no autoplay);
/// - the poster stays until the first frame, with a spinner if the first segment is slow;
/// - playback starts on the lowest rung, and a pill shows the rung on screen ("144p · 47 kbps").
class ProcessVideo extends ConsumerStatefulWidget {
  final Product product;
  const ProcessVideo({super.key, required this.product});

  @override
  ConsumerState<ProcessVideo> createState() => _ProcessVideoState();
}

class _ProcessVideoState extends ConsumerState<ProcessVideo> {
  Playback? _playback;
  Timer? _spinnerDelay;
  bool _showSpinner = false;

  void _start() {
    final config = ref.read(appConfigProvider);
    final playback = ref.read(playbackFactoryProvider)(config.player.streamUri(widget.product.hlsUrl!), config.player);
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
    final t = context.tokens;
    final p = widget.product;
    final playback = _playback;
    final canPlay = p.videoStatus == 'ready' && p.hlsUrl != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.radius.md),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: playback == null
            ? Stack(fit: StackFit.expand, children: [
                ProductPoster(tags: p.tags, thumbnailUrl: p.thumbnailUrl),
                if (canPlay) Center(child: _BigButton(icon: Icons.play_arrow_rounded, label: context.s('product.play'), onTap: _start)),
                Positioned(
                  left: t.space.md,
                  bottom: t.space.md,
                  right: t.space.md,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _Pill(icon: Icons.network_cell, text: context.s('product.slow_network_note')),
                  ),
                ),
              ])
            : ValueListenableBuilder(
                valueListenable: playback.state,
                builder: (context, s, _) => _Playing(
                  product: p,
                  playback: playback,
                  state: s,
                  showSpinner: _showSpinner,
                  onRetry: _restart,
                ),
              ),
      ),
    );
  }
}

class _Playing extends ConsumerWidget {
  final Product product;
  final Playback playback;
  final PlaybackState state;
  final bool showSpinner;
  final VoidCallback onRetry;
  const _Playing({
    required this.product,
    required this.playback,
    required this.state,
    required this.showSpinner,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final config = ref.watch(appConfigProvider);
    final rules = config.player;
    final s = state;
    final failed = s.phase == PlaybackPhase.error;
    final playing = s.phase == PlaybackPhase.playing;
    final rung = s.rung;
    final rungText = rung == null
        ? context.s('product.slow_network_note')
        : rung.bitrateBps > 0
            ? context.s('product.rung', {
                'height': rules.rungLabel(height: rung.height, bitrateBps: rung.bitrateBps).height,
                'kbps': rules.rungLabel(height: rung.height, bitrateBps: rung.bitrateBps).kbps,
              })
            : context.s('product.rung_height_only', {'height': rung.height});
    final estimate = s.estimateBps;

    return Stack(fit: StackFit.expand, children: [
      ColoredBox(color: t.scrim),
      playback.view(),
      if (!s.firstFrame && rules.showPosterUntilFirstFrame && !failed)
        IgnorePointer(child: ProductPoster(tags: product.tags, thumbnailUrl: product.thumbnailUrl)),
      // Tap the picture to play or pause.
      if (!failed)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => playing ? playback.pause() : playback.play(),
          ),
        ),
      if (showSpinner && !failed)
        Center(
          child: Semantics(
            label: context.s('product.buffering'),
            child: Container(
              padding: EdgeInsets.all(t.space.md),
              decoration: BoxDecoration(color: t.card, shape: BoxShape.circle),
              child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3, color: t.brand)),
            ),
          ),
        ),
      if (!playing && !showSpinner && !failed && s.firstFrame)
        Center(child: _BigButton(icon: Icons.play_arrow_rounded, label: context.s('product.play'), onTap: playback.play)),
      if (failed)
        // Scales down rather than overflow on a small phone's 16:9 box.
        Padding(
          padding: EdgeInsets.all(t.space.md),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                padding: EdgeInsets.all(t.space.lg),
                decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius.md)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(context.s('product.video_error'), style: context.type.body, textAlign: TextAlign.center),
                  SizedBox(height: t.space.md),
                  AppButton(context.s('common.retry'), icon: Icons.refresh, onPressed: onRetry, size: ButtonSize.sm),
                ]),
              ),
            ),
          ),
        ),
      if (!failed)
        Positioned(
          left: t.space.md,
          top: t.space.md,
          right: t.space.md,
          child: Wrap(spacing: t.space.xs, runSpacing: t.space.xs, children: [
            _Pill(icon: Icons.network_cell, text: rungText),
            if (config.env.devTools && estimate != null)
              _Pill(icon: Icons.speed, text: context.s('product.network_estimate', {'kbps': (estimate / 1000).round()})),
          ]),
        ),
      if (!failed && s.firstFrame)
        Positioned(left: t.space.sm, right: t.space.sm, bottom: t.space.sm, child: _Controls(playback: playback, state: s)),
    ]);
  }
}

class _Controls extends StatelessWidget {
  final Playback playback;
  final PlaybackState state;
  const _Controls({required this.playback, required this.state});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final playing = state.phase == PlaybackPhase.playing;
    final total = state.duration.inMilliseconds;
    final at = state.position.inMilliseconds.clamp(0, total > 0 ? total : 0);
    return Container(
      padding: EdgeInsets.only(right: t.space.md),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius.pill)),
      child: Row(children: [
        IconButton(
          tooltip: context.s(playing ? 'product.pause' : 'product.play'),
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: t.ink),
          onPressed: playing ? playback.pause : playback.play,
        ),
        Expanded(
          child: Semantics(
            label: context.s('product.seek'),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: t.brand,
                inactiveTrackColor: t.hair,
                thumbColor: t.brand,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: total > 0 ? at / total : 0,
                onChanged: total > 0 ? (v) => playback.seekTo(Duration(milliseconds: (v * total).round())) : null,
              ),
            ),
          ),
        ),
        SizedBox(width: t.space.sm),
        Text(
          context.s('product.time', {'position': formatDuration(state.position), 'duration': formatDuration(state.duration)}),
          style: context.type.caption.copyWith(color: t.ink, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ]),
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BigButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: t.brand,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: EdgeInsets.all(t.space.lg), child: Icon(icon, size: 36, color: t.onBrand)),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.xs),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: t.brandInk),
        SizedBox(width: t.space.xs),
        Flexible(
          child: Text(text, style: context.type.caption.copyWith(color: t.ink), overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}
