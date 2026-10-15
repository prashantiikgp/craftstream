/// Shape of assets/config/dev/mock.yml: the in-app fake backend's timing and sample data (MOCK_DATA=true).
library;

import 'package:json_annotation/json_annotation.dart';

part 'mock_schema.g.dart';

@JsonSerializable()
class MockSchema {
  final int latencyMs;
  final int chunkDelayMs;
  final int processingSeconds;
  final String artisanName;
  final String currency;
  final MockPageSizesSchema pageSizes;
  final MockUploadPolicySchema uploadPolicy;

  /// `{id}` is the product id.
  final String hlsUrl;
  final String uploadUrl;
  final Map<String, MockLogEventSchema> logEvents;
  final List<MockVideoSchema> videos;
  final List<MockProductSchema> products;

  const MockSchema({
    required this.latencyMs,
    required this.chunkDelayMs,
    required this.processingSeconds,
    required this.artisanName,
    required this.currency,
    required this.pageSizes,
    required this.uploadPolicy,
    required this.hlsUrl,
    required this.uploadUrl,
    required this.logEvents,
    required this.videos,
    required this.products,
  });

  factory MockSchema.fromJson(Map<String, dynamic> json) => _$MockSchemaFromJson(json);
}

@JsonSerializable()
class MockPageSizesSchema {
  final int products;
  final int logs;

  const MockPageSizesSchema({required this.products, required this.logs});

  factory MockPageSizesSchema.fromJson(Map<String, dynamic> json) => _$MockPageSizesSchemaFromJson(json);
}

@JsonSerializable()
class MockUploadPolicySchema {
  final int maxDurationSeconds;
  final List<String> allowedMimeTypes;
  final int chunkSizeBytes;

  const MockUploadPolicySchema({
    required this.maxDurationSeconds,
    required this.allowedMimeTypes,
    required this.chunkSizeBytes,
  });

  factory MockUploadPolicySchema.fromJson(Map<String, dynamic> json) => _$MockUploadPolicySchemaFromJson(json);
}

@JsonSerializable()
class MockLogEventSchema {
  final String group;
  final String level;
  final String message;

  const MockLogEventSchema({required this.group, required this.level, required this.message});

  factory MockLogEventSchema.fromJson(Map<String, dynamic> json) => _$MockLogEventSchemaFromJson(json);
}

@JsonSerializable()
class MockVideoSchema {
  final String name;
  final int sizeBytes;
  final String mimeType;
  final int seconds;

  const MockVideoSchema({required this.name, required this.sizeBytes, required this.mimeType, required this.seconds});

  factory MockVideoSchema.fromJson(Map<String, dynamic> json) => _$MockVideoSchemaFromJson(json);
}

@JsonSerializable()
class MockProductSchema {
  final String id;
  final String title;
  final String artisan;
  final double price;
  final List<String> tags;

  /// A video status (ui/status.yml).
  final String status;

  /// Owned by this device's artisan (Your products).
  final bool mine;

  /// Local time, `2026-10-01T01:00:00`.
  final String createdAt;
  final String description;

  const MockProductSchema({
    required this.id,
    required this.title,
    required this.artisan,
    required this.price,
    required this.tags,
    required this.status,
    this.mine = false,
    required this.createdAt,
    required this.description,
  });

  factory MockProductSchema.fromJson(Map<String, dynamic> json) => _$MockProductSchemaFromJson(json);
}
