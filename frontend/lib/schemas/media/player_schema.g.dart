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
        'poster',
        'autoplay_in_grids',
        'autoplay_on_product_page',
        'sample_stream_url',
      ],
    );
    final val = PlayerSchema(
      startOnLowestRung: $checkedConvert(
        'start_on_lowest_rung',
        (v) => v as bool,
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
    'initialBandwidthBps': 'initial_bandwidth_bps',
    'minBufferToStartSeconds': 'min_buffer_to_start_seconds',
    'maxBufferSeconds': 'max_buffer_seconds',
    'upswitchSafetyFactor': 'upswitch_safety_factor',
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
