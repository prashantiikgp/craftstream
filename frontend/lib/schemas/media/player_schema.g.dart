// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayerSchema _$PlayerSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PlayerSchema',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'start_on_lowest_rung',
        'initial_bandwidth_bps',
        'min_buffer_to_start_seconds',
        'max_buffer_seconds',
        'upswitch_safety_factor',
        'native_upswitch_when_buffered_seconds',
        'native_upswitch_within_seconds',
        'poster',
        'autoplay_in_grids',
        'autoplay_on_product_page',
        'sample_stream_url',
        'lowest_rung_budget_kbps',
        'master_fetch_timeout_seconds',
        'hls_mime_type',
        'web_video',
        'media_error_recoveries',
      ],
    );
    final val = PlayerSchema(
      startOnLowestRung: $checkedConvert(
        'start_on_lowest_rung',
        (v) => v as bool,
      ),
      lowestRungBudgetKbps: $checkedConvert(
        'lowest_rung_budget_kbps',
        (v) => (v as num).toInt(),
      ),
      masterFetchTimeoutSeconds: $checkedConvert(
        'master_fetch_timeout_seconds',
        (v) => (v as num).toDouble(),
      ),
      hlsMimeType: $checkedConvert('hls_mime_type', (v) => v as String),
      webVideo: $checkedConvert(
        'web_video',
        (v) => WebVideoSchema.fromJson(v as Map<String, dynamic>),
      ),
      mediaErrorRecoveries: $checkedConvert(
        'media_error_recoveries',
        (v) => (v as num).toInt(),
      ),
      initialBandwidthBps: $checkedConvert(
        'initial_bandwidth_bps',
        (v) => (v as num).toInt(),
      ),
      minBufferToStartSeconds: $checkedConvert(
        'min_buffer_to_start_seconds',
        (v) => (v as num).toDouble(),
      ),
      maxBufferSeconds: $checkedConvert(
        'max_buffer_seconds',
        (v) => (v as num).toDouble(),
      ),
      upswitchSafetyFactor: $checkedConvert(
        'upswitch_safety_factor',
        (v) => (v as num).toDouble(),
      ),
      nativeUpswitchWhenBufferedSeconds: $checkedConvert(
        'native_upswitch_when_buffered_seconds',
        (v) => (v as num).toDouble(),
      ),
      nativeUpswitchWithinSeconds: $checkedConvert(
        'native_upswitch_within_seconds',
        (v) => (v as num).toDouble(),
      ),
      poster: $checkedConvert(
        'poster',
        (v) => PosterSchema.fromJson(v as Map<String, dynamic>),
      ),
      autoplayInGrids: $checkedConvert('autoplay_in_grids', (v) => v as bool),
      autoplayOnProductPage: $checkedConvert(
        'autoplay_on_product_page',
        (v) => v as bool,
      ),
      sampleStreamUrl: $checkedConvert('sample_stream_url', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'startOnLowestRung': 'start_on_lowest_rung',
    'lowestRungBudgetKbps': 'lowest_rung_budget_kbps',
    'masterFetchTimeoutSeconds': 'master_fetch_timeout_seconds',
    'hlsMimeType': 'hls_mime_type',
    'webVideo': 'web_video',
    'mediaErrorRecoveries': 'media_error_recoveries',
    'initialBandwidthBps': 'initial_bandwidth_bps',
    'minBufferToStartSeconds': 'min_buffer_to_start_seconds',
    'maxBufferSeconds': 'max_buffer_seconds',
    'upswitchSafetyFactor': 'upswitch_safety_factor',
    'nativeUpswitchWhenBufferedSeconds':
        'native_upswitch_when_buffered_seconds',
    'nativeUpswitchWithinSeconds': 'native_upswitch_within_seconds',
    'autoplayInGrids': 'autoplay_in_grids',
    'autoplayOnProductPage': 'autoplay_on_product_page',
    'sampleStreamUrl': 'sample_stream_url',
  },
);

PosterSchema _$PosterSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PosterSchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'show_until_first_frame',
            'buffering_indicator_after_ms',
          ],
        );
        final val = PosterSchema(
          showUntilFirstFrame: $checkedConvert(
            'show_until_first_frame',
            (v) => v as bool,
          ),
          bufferingIndicatorAfterMs: $checkedConvert(
            'buffering_indicator_after_ms',
            (v) => (v as num).toInt(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'showUntilFirstFrame': 'show_until_first_frame',
        'bufferingIndicatorAfterMs': 'buffering_indicator_after_ms',
      },
    );

WebVideoSchema _$WebVideoSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'WebVideoSchema',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const ['object_fit', 'plays_inline', 'controls', 'preload'],
    );
    final val = WebVideoSchema(
      objectFit: $checkedConvert('object_fit', (v) => v as String),
      playsInline: $checkedConvert('plays_inline', (v) => v as bool),
      controls: $checkedConvert('controls', (v) => v as bool),
      preload: $checkedConvert('preload', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {'objectFit': 'object_fit', 'playsInline': 'plays_inline'},
);
