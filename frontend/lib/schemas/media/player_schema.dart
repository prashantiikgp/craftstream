/// Shape of assets/config/media/player.yml: low-bandwidth playback settings.
library;

import 'package:json_annotation/json_annotation.dart';

part 'player_schema.g.dart';

@JsonSerializable()
class PlayerSchema {
  final bool startOnLowestRung;
  final int initialBandwidthBps;
  final double minBufferToStartSeconds;
  final double maxBufferSeconds;
  final double upswitchSafetyFactor;
  final double nativeUpswitchWhenBufferedSeconds;
  final double nativeUpswitchWithinSeconds;
  final PosterSchema poster;
  final bool autoplayInGrids;
  final bool autoplayOnProductPage;
  final String sampleStreamUrl;

  const PlayerSchema({
    required this.startOnLowestRung,
    required this.initialBandwidthBps,
    required this.minBufferToStartSeconds,
    required this.maxBufferSeconds,
    required this.upswitchSafetyFactor,
    required this.nativeUpswitchWhenBufferedSeconds,
    required this.nativeUpswitchWithinSeconds,
    required this.poster,
    required this.autoplayInGrids,
    required this.autoplayOnProductPage,
    required this.sampleStreamUrl,
  });

  factory PlayerSchema.fromJson(Map<String, dynamic> json) => _$PlayerSchemaFromJson(json);
}

@JsonSerializable()
class PosterSchema {
  final bool showUntilFirstFrame;
  final int bufferingIndicatorAfterMs;

  const PosterSchema({required this.showUntilFirstFrame, required this.bufferingIndicatorAfterMs});

  factory PosterSchema.fromJson(Map<String, dynamic> json) => _$PosterSchemaFromJson(json);
}
