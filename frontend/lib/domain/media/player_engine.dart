/// Low-bandwidth playback settings from player.yml. Pure Dart: the F5 player reads its config from here.
library;

import '../../schemas/media/player_schema.dart';

class PlayerRulesError implements Exception {
  final String message;
  const PlayerRulesError(this.message);
  @override
  String toString() => 'player.yml: $message';
}

class PlayerEngine {
  /// The lowest rung must stay at or under this on the wire (hard rule 2, R5).
  static const lowestRungBudgetBps = 50000;

  final PlayerSchema rules;

  PlayerEngine(this.rules) {
    if (!rules.startOnLowestRung) {
      throw const PlayerRulesError('start_on_lowest_rung must be true (the player starts on the lowest rung)');
    }
    if (rules.initialBandwidthBps <= 0 || rules.initialBandwidthBps > lowestRungBudgetBps) {
      throw const PlayerRulesError('initial_bandwidth_bps must be between 1 and 50000 so the first pick is the lowest rung');
    }
    if (rules.minBufferToStartSeconds <= 0 || rules.maxBufferSeconds <= rules.minBufferToStartSeconds) {
      throw const PlayerRulesError('need 0 < min_buffer_to_start_seconds < max_buffer_seconds');
    }
    if (rules.upswitchSafetyFactor < 1) throw const PlayerRulesError('upswitch_safety_factor must be >= 1');
    if (rules.autoplayInGrids) throw const PlayerRulesError('autoplay_in_grids must be false (grids show posters only)');
    final sample = Uri.tryParse(rules.sampleStreamUrl);
    if (sample == null || sample.scheme != 'https' || !sample.path.endsWith('.m3u8')) {
      throw const PlayerRulesError('sample_stream_url must be an https .m3u8 URL');
    }
  }

  /// The stream to play for a product's `hls_url`. Mock data (`mock://…`) has no media bucket, so it plays the
  /// sample stream from player.yml.
  Uri streamUri(String hlsUrl) => Uri.parse(hlsUrl.startsWith('mock://') ? rules.sampleStreamUrl : hlsUrl);

  int get initialBandwidthBps => rules.initialBandwidthBps;
  Duration get minBufferToStart => _seconds(rules.minBufferToStartSeconds);
  Duration get maxBuffer => _seconds(rules.maxBufferSeconds);
  Duration get bufferingIndicatorDelay => Duration(milliseconds: rules.poster.bufferingIndicatorAfterMs);
  bool get showPosterUntilFirstFrame => rules.poster.showUntilFirstFrame;
  bool get autoplayOnProductPage => rules.autoplayOnProductPage;

  /// hls.js settings for Chrome (F5 passes these to the web player).
  Map<String, Object> hlsJsConfig() => {
        'startLevel': 0,
        'abrEwmaDefaultEstimate': rules.initialBandwidthBps,
        'abrBandWidthUpFactor': 1 / rules.upswitchSafetyFactor,
        'maxBufferLength': rules.maxBufferSeconds,
        'maxMaxBufferLength': rules.maxBufferSeconds, // hls.js would otherwise grow the buffer up to 600 s
        'testBandwidth': false,
      };

  /// What the rung overlay shows, e.g. `(height: 144, kbps: 47)`. Bitrates round to whole kbps (minimum 1).
  ({int height, int kbps}) rungLabel({required int height, required int bitrateBps}) =>
      (height: height, kbps: bitrateBps <= 0 ? 0 : (bitrateBps / 1000).round().clamp(1, 1 << 30));

  /// Should the player step up to a rung of [rungBps] given the measured bandwidth?
  bool canUpswitch({required int measuredBps, required int rungBps}) =>
      measuredBps >= rungBps * rules.upswitchSafetyFactor;

  static Duration _seconds(double s) => Duration(milliseconds: (s * 1000).round());
}
