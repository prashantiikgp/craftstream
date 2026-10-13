import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/media/player_engine.dart';
import 'package:craftstream/schemas/media/player_schema.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(hls['abrEwmaDefaultEstimate'] as int, lessThanOrEqualTo(PlayerEngine.lowestRungBudgetBps));
    expect(hls['testBandwidth'], false);
    expect(hls['maxMaxBufferLength'], hls['maxBufferLength']);
  });

  test('mock videos play the sample stream; real ones play as given', () {
    expect(engine.streamUri('mock://media/p_01/master.m3u8').toString(), engine.rules.sampleStreamUrl);
    const real = 'https://storage.googleapis.com/craftstream-media/p_1/manifest.m3u8';
    expect(engine.streamUri(real).toString(), real);
    expect(() => PlayerEngine(rules((t) => t.replaceFirst(RegExp(r'sample_stream_url: .*'), 'sample_stream_url: http://x/a.mp4'))),
        throwsA(isA<PlayerRulesError>()));
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

  test('rules that would break low-bandwidth playback are rejected', () {
    expect(() => PlayerEngine(rules((t) => t.replaceFirst('start_on_lowest_rung: true', 'start_on_lowest_rung: false'))),
        throwsA(isA<PlayerRulesError>()));
    expect(() => PlayerEngine(rules((t) => t.replaceFirst('initial_bandwidth_bps: 40000', 'initial_bandwidth_bps: 800000'))),
        throwsA(isA<PlayerRulesError>()));
    expect(() => PlayerEngine(rules((t) => t.replaceFirst('autoplay_in_grids: false', 'autoplay_in_grids: true'))),
        throwsA(isA<PlayerRulesError>()));
    expect(() => rules((t) => '$t\nautoplay: true\n'), throwsA(isA<ConfigError>()));
  });
}
