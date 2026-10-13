// The product page's process video with a fake playback: nothing loads before the tap, the poster stays
// until the first frame, a spinner appears only after the delay in player.yml, the rung pill shows
// "144p · 47 kbps", and an error offers a retry that starts a fresh session.
import 'package:craftstream/core/config.dart';
import 'package:craftstream/domain/media/player_engine.dart';
import 'package:craftstream/shared/player/playback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

class FakePlayback implements Playback {
  final Uri stream;
  final PlayerEngine rules;
  final _state = ValueNotifier(const PlaybackState());
  int starts = 0, plays = 0, pauses = 0;
  bool disposed = false;
  FakePlayback(this.stream, this.rules);

  void emit(PlaybackState s) => _state.value = s;

  @override
  ValueListenable<PlaybackState> get state => _state;
  @override
  Future<void> start() async => starts++;
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Widget view() => const SizedBox.expand(key: Key('fake-video'));
  @override
  void dispose() => disposed = true;
}

void main() {
  late AppConfig c;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    c = await testConfig();
  });

  Future<List<FakePlayback>> open(WidgetTester tester, {String id = 'p_01'}) async {
    final made = <FakePlayback>[];
    await pumpApp(tester, c, location: '/product/$id', overrides: [
      playbackFactoryProvider.overrideWithValue((uri, rules) {
        final p = FakePlayback(uri, rules);
        made.add(p);
        return p;
      }),
    ]);
    return made;
  }

  Finder playButton() => find.bySemanticsLabel(str(c, 'product.play'));

  testWidgets('nothing loads until the buyer taps play; mock videos use the sample stream', (tester) async {
    final made = await open(tester);
    expect(made, isEmpty);
    expect(find.text(str(c, 'product.slow_network_note')), findsOneWidget);

    await tester.tap(playButton());
    await settle(tester, frames: 2);
    expect(made, hasLength(1));
    expect(made.single.starts, 1);
    expect(made.single.stream.toString(), c.player.rules.sampleStreamUrl);
  });

  testWidgets('poster until the first frame, spinner only after the delay, then the rung pill', (tester) async {
    final made = await open(tester);
    await tester.tap(playButton());
    await tester.pump();
    final p = made.single;
    final spinner = find.bySemanticsLabel(str(c, 'product.buffering'));

    // Buffering the first segment: poster stays, no spinner yet.
    expect(find.byKey(const Key('fake-video')), findsOneWidget);
    expect(spinner, findsNothing);
    await tester.pump(c.player.bufferingIndicatorDelay + const Duration(milliseconds: 50));
    expect(spinner, findsOneWidget);

    p.emit(const PlaybackState(
      phase: PlaybackPhase.playing,
      buffering: false,
      firstFrame: true,
      position: Duration(seconds: 5),
      duration: Duration(minutes: 12, seconds: 40),
      rung: Rung(height: 144, bitrateBps: 47080),
      estimateBps: 45200,
    ));
    await tester.pump();
    expect(spinner, findsNothing);
    expect(find.text(str(c, 'product.rung', {'height': 144, 'kbps': 47})), findsOneWidget);
    expect(find.text(str(c, 'product.network_estimate', {'kbps': 45})), findsOneWidget); // DEV_TOOLS on
    expect(find.text(str(c, 'product.time', {'position': '0:05', 'duration': '12:40'})), findsOneWidget);

    await tester.tap(find.byTooltip(str(c, 'product.pause')));
    expect(p.pauses, 1);
  });

  testWidgets('a quick wait never flashes the spinner', (tester) async {
    final made = await open(tester);
    await tester.tap(playButton());
    await tester.pump(c.player.bufferingIndicatorDelay ~/ 2);
    made.single.emit(const PlaybackState(phase: PlaybackPhase.playing, buffering: false, firstFrame: true));
    await tester.pump(c.player.bufferingIndicatorDelay);
    expect(find.bySemanticsLabel(str(c, 'product.buffering')), findsNothing);
  });

  testWidgets('an error offers a retry with a fresh session', (tester) async {
    final made = await open(tester);
    await tester.tap(playButton());
    await tester.pump();
    made.single.emit(const PlaybackState(phase: PlaybackPhase.error, buffering: false));
    await tester.pump();
    expect(find.text(str(c, 'product.video_error')), findsOneWidget);

    await tester.tap(find.text(str(c, 'common.retry')));
    await tester.pump();
    expect(made, hasLength(2));
    expect(made.first.disposed, isTrue);
    expect(made.last.starts, 1);
    expect(find.text(str(c, 'product.video_error')), findsNothing);
  });

  testWidgets('a product whose video is not ready has no play button', (tester) async {
    await open(tester, id: 'p_13'); // processing
    expect(playButton(), findsNothing);
  });

  testWidgets('leaving the page disposes the session', (tester) async {
    final made = await open(tester);
    await tester.tap(playButton());
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(made.single.disposed, isTrue);
  });
}
