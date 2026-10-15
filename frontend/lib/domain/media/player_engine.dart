/// Low-bandwidth playback settings from player.yml. Pure Dart: the F5 player reads its config from here.
library;

import '../../schemas/media/player_schema.dart';

class PlayerRulesError implements Exception {
  final String message;
  const PlayerRulesError(this.message);
  @override
  String toString() => 'player.yml: $message';
}

/// Values the browser accepts for the `<video>` settings in `web_video`.
const _objectFits = {'contain', 'cover', 'fill', 'none', 'scale-down'};
const _preloads = {'none', 'metadata', 'auto'};

class PlayerEngine {
  final PlayerSchema rules;

  PlayerEngine(this.rules) {
    if (!rules.startOnLowestRung) {
      throw const PlayerRulesError('start_on_lowest_rung must be true (the player starts on the lowest rung)');
    }
    if (rules.lowestRungBudgetKbps <= 0) throw const PlayerRulesError('lowest_rung_budget_kbps must be > 0');
    if (rules.initialBandwidthBps <= 0 || rules.initialBandwidthBps > lowestRungBudgetBps) {
      throw PlayerRulesError(
        'initial_bandwidth_bps must be between 1 and $lowestRungBudgetBps so the first pick is the lowest rung',
      );
    }
    if (rules.masterFetchTimeoutSeconds <= 0) throw const PlayerRulesError('master_fetch_timeout_seconds must be > 0');
    if (!RegExp(r'^[a-z]+/[a-z0-9.+-]+$').hasMatch(rules.hlsMimeType)) {
      throw const PlayerRulesError('hls_mime_type must be a MIME type (type/subtype)');
    }
    if (!_objectFits.contains(rules.webVideo.objectFit)) {
      throw PlayerRulesError('web_video.object_fit must be one of ${_objectFits.join(', ')}');
    }
    if (!_preloads.contains(rules.webVideo.preload)) {
      throw PlayerRulesError('web_video.preload must be one of ${_preloads.join(', ')}');
    }
    if (rules.mediaErrorRecoveries < 0) throw const PlayerRulesError('media_error_recoveries must be >= 0');
    if (rules.minBufferToStartSeconds <= 0 || rules.maxBufferSeconds <= rules.minBufferToStartSeconds) {
      throw const PlayerRulesError('need 0 < min_buffer_to_start_seconds < max_buffer_seconds');
    }
    if (rules.upswitchSafetyFactor < 1) throw const PlayerRulesError('upswitch_safety_factor must be >= 1');
    if (rules.nativeUpswitchWhenBufferedSeconds <= rules.minBufferToStartSeconds ||
        rules.nativeUpswitchWithinSeconds <= 0) {
      throw const PlayerRulesError(
        'native_upswitch_when_buffered_seconds must exceed min_buffer_to_start_seconds and native_upswitch_within_seconds must be > 0',
      );
    }
    if (rules.autoplayInGrids) {
      throw const PlayerRulesError('autoplay_in_grids must be false (grids show posters only)');
    }
    final sample = Uri.tryParse(rules.sampleStreamUrl);
    if (sample == null || sample.scheme != 'https' || !sample.path.endsWith('.m3u8')) {
      throw const PlayerRulesError('sample_stream_url must be an https .m3u8 URL');
    }
  }

  /// The stream to play for a product's `hls_url`. Mock data (`mock://…`) has no media bucket, so it plays the
  /// sample stream from player.yml.
  Uri streamUri(String hlsUrl) => Uri.parse(hlsUrl.startsWith('mock://') ? rules.sampleStreamUrl : hlsUrl);

  /// The lowest rung must stay at or under this on the wire (hard rule 2, R5; ladder.yml's budget).
  int get lowestRungBudgetBps => rules.lowestRungBudgetKbps * 1000;

  /// Android fetches the master playlist itself; past this it plays the stream as is.
  Duration get masterFetchTimeout => _seconds(rules.masterFetchTimeoutSeconds);

  /// The HLS playlist MIME type.
  String get hlsMimeType => rules.hlsMimeType;

  /// Chrome's `<video>` settings.
  WebVideoSchema get webVideo => rules.webVideo;

  /// Fatal media errors hls.js recovers from before the player shows its error state.
  int get mediaErrorRecoveries => rules.mediaErrorRecoveries;

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

  /// Android: leave the lowest-rung-only playlist for the full ladder? Only when the buffer is well ahead early
  /// in playback, which a link slower than the lowest rung can never manage (see player.yml).
  bool shouldUpswitchNative({required Duration bufferedAhead, required Duration position}) =>
      position <= _seconds(rules.nativeUpswitchWithinSeconds) &&
      bufferedAhead >= _seconds(rules.nativeUpswitchWhenBufferedSeconds);

  static Duration _seconds(double s) => Duration(milliseconds: (s * 1000).round());
}
