import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/media/player_engine.dart';
import 'package:craftstream/schemas/media/player_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const path = 'assets/config/media/player.yml';
PlayerSchema rules([String Function(String)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, PlayerSchema.fromJson);
}

void main() {
  final engine = PlayerEngine(rules());

  test('the player starts on the lowest rung with a low first guess', () {
    final hls = engine.hlsJsConfig();
    expect(hls['startLevel'], 0);
    expect(hls['abrEwmaDefaultEstimate'] as int, lessThanOrEqualTo(engine.lowestRungBudgetBps));
    expect(hls['testBandwidth'], false);
    expect(hls['maxMaxBufferLength'], hls['maxBufferLength']);
  });

  test("the 50 kbps budget is the backend ladder's budget, not a second number", () {
    final ladder = loadYaml(File('../backend/config/media/ladder.yml').readAsStringSync()) as YamlMap;
    expect(engine.rules.lowestRungBudgetKbps, ladder['max_lowest_rung_total_kbps']);
    expect(engine.lowestRungBudgetBps, 50000);
    expect(
      () => PlayerEngine(rules((t) => t.replaceFirst('lowest_rung_budget_kbps: 50', 'lowest_rung_budget_kbps: 30'))),
      throwsA(isA<PlayerRulesError>()),
      reason: 'the first bandwidth guess (40 kbps) may not exceed the budget',
    );
  });

  test('fetch timeout, playlist type, web <video> and media-error recovery come from player.yml', () {
    expect(engine.masterFetchTimeout, const Duration(seconds: 20));
    expect(engine.hlsMimeType, 'application/vnd.apple.mpegurl');
    expect(engine.webVideo.objectFit, 'contain');
    expect(engine.webVideo.playsInline, isTrue);
    expect(engine.webVideo.controls, isFalse);
    expect(engine.webVideo.preload, 'none');
    expect(engine.mediaErrorRecoveries, 1);
    expect(
      () => PlayerEngine(rules((t) => t.replaceFirst('preload: none', 'preload: everything'))),
      throwsA(isA<PlayerRulesError>()),
    );
    expect(
      () => PlayerEngine(rules((t) => t.replaceFirst('object_fit: contain', 'object_fit: stretch'))),
      throwsA(isA<PlayerRulesError>()),
    );
    expect(
      () => PlayerEngine(rules((t) => t.replaceFirst('media_error_recoveries: 1', 'media_error_recoveries: -1'))),
      throwsA(isA<PlayerRulesError>()),
    );
  });

  test('mock videos play the sample stream; real ones play as given', () {
    expect(engine.streamUri('mock://media/p_01/master.m3u8').toString(), engine.rules.sampleStreamUrl);
    const real = 'https://storage.googleapis.com/craftstream-media/p_1/manifest.m3u8';
    expect(engine.streamUri(real).toString(), real);
    expect(
      () => PlayerEngine(
        rules((t) => t.replaceFirst(RegExp(r'sample_stream_url: .*'), 'sample_stream_url: http://x/a.mp4')),
      ),
      throwsA(isA<PlayerRulesError>()),
    );
  });

  test('the rung label rounds to whole kbps', () {
    expect(engine.rungLabel(height: 144, bitrateBps: 47080), (height: 144, kbps: 47));
    expect(engine.rungLabel(height: 144, bitrateBps: 300), (height: 144, kbps: 1));
    expect(engine.rungLabel(height: 360, bitrateBps: 0), (height: 360, kbps: 0));
  });

  test('buffer and poster settings come through', () {
    expect(engine.minBufferToStart, const Duration(seconds: 4));
    expect(engine.maxBuffer, const Duration(seconds: 30));
    expect(engine.showPosterUntilFirstFrame, isTrue);
    expect(engine.autoplayOnProductPage, isFalse);
  });

  test('stepping up needs headroom', () {
    expect(engine.canUpswitch(measuredBps: 100000, rungBps: 90000), isFalse);
    expect(engine.canUpswitch(measuredBps: 130000, rungBps: 90000), isTrue);
  });

  test('Android leaves the lowest-rung-only playlist only when the buffer is well ahead early on', () {
    // A fast link: 20 s buffered within the first minute.
    expect(
      engine.shouldUpswitchNative(bufferedAhead: const Duration(seconds: 25), position: const Duration(seconds: 5)),
      isTrue,
    );
    // A slow link never buffers that far ahead...
    expect(
      engine.shouldUpswitchNative(bufferedAhead: const Duration(seconds: 6), position: const Duration(seconds: 30)),
      isFalse,
    );
    // ...and a slim surplus that adds up over minutes does not count either.
    expect(
      engine.shouldUpswitchNative(bufferedAhead: const Duration(seconds: 25), position: const Duration(minutes: 5)),
      isFalse,
    );
    expect(
      () => PlayerEngine(
        rules(
          (t) =>
              t.replaceFirst('native_upswitch_when_buffered_seconds: 20', 'native_upswitch_when_buffered_seconds: 2'),
        ),
      ),
      throwsA(isA<PlayerRulesError>()),
    );
  });

  test('rules that would break low-bandwidth playback are rejected', () {
    expect(
      () => PlayerEngine(rules((t) => t.replaceFirst('start_on_lowest_rung: true', 'start_on_lowest_rung: false'))),
      throwsA(isA<PlayerRulesError>()),
    );
    expect(
      () => PlayerEngine(rules((t) => t.replaceFirst('initial_bandwidth_bps: 40000', 'initial_bandwidth_bps: 800000'))),
      throwsA(isA<PlayerRulesError>()),
    );
    expect(
      () => PlayerEngine(rules((t) => t.replaceFirst('autoplay_in_grids: false', 'autoplay_in_grids: true'))),
      throwsA(isA<PlayerRulesError>()),
    );
    expect(() => rules((t) => '$t\nautoplay: true\n'), throwsA(isA<ConfigError>()));
  });
}
