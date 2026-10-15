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
  final int lowestRungBudgetKbps;
  final double masterFetchTimeoutSeconds;
  final String hlsMimeType;
  final WebVideoSchema webVideo;
  final int mediaErrorRecoveries;

  const PlayerSchema({
    required this.startOnLowestRung,
    required this.lowestRungBudgetKbps,
    required this.masterFetchTimeoutSeconds,
    required this.hlsMimeType,
    required this.webVideo,
    required this.mediaErrorRecoveries,
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

/// Chrome: the `<video>` element hls.js plays into.
@JsonSerializable()
class WebVideoSchema {
  /// CSS object-fit.
  final String objectFit;
  final bool playsInline;
  final bool controls;

  /// none | metadata | auto
  final String preload;

  const WebVideoSchema({
    required this.objectFit,
    required this.playsInline,
    required this.controls,
    required this.preload,
  });

  factory WebVideoSchema.fromJson(Map<String, dynamic> json) => _$WebVideoSchemaFromJson(json);
}
