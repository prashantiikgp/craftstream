// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mock_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MockSchema _$MockSchemaFromJson(Map<String, dynamic> json) => $checkedCreate(
  'MockSchema',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'latency_ms',
        'chunk_delay_ms',
        'processing_seconds',
        'artisan_name',
        'currency',
        'page_sizes',
        'upload_policy',
        'hls_url',
        'upload_url',
        'log_events',
        'videos',
        'products',
      ],
    );
    final val = MockSchema(
      latencyMs: $checkedConvert('latency_ms', (v) => (v as num).toInt()),
      chunkDelayMs: $checkedConvert(
        'chunk_delay_ms',
        (v) => (v as num).toInt(),
      ),
      processingSeconds: $checkedConvert(
        'processing_seconds',
        (v) => (v as num).toInt(),
      ),
      artisanName: $checkedConvert('artisan_name', (v) => v as String),
      currency: $checkedConvert('currency', (v) => v as String),
      pageSizes: $checkedConvert(
        'page_sizes',
        (v) => MockPageSizesSchema.fromJson(v as Map<String, dynamic>),
      ),
      uploadPolicy: $checkedConvert(
        'upload_policy',
        (v) => MockUploadPolicySchema.fromJson(v as Map<String, dynamic>),
      ),
      hlsUrl: $checkedConvert('hls_url', (v) => v as String),
      uploadUrl: $checkedConvert('upload_url', (v) => v as String),
      logEvents: $checkedConvert(
        'log_events',
        (v) => (v as Map<String, dynamic>).map(
          (k, e) => MapEntry(
            k,
            MockLogEventSchema.fromJson(e as Map<String, dynamic>),
          ),
        ),
      ),
      videos: $checkedConvert(
        'videos',
        (v) => (v as List<dynamic>)
            .map((e) => MockVideoSchema.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      products: $checkedConvert(
        'products',
        (v) => (v as List<dynamic>)
            .map((e) => MockProductSchema.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'latencyMs': 'latency_ms',
    'chunkDelayMs': 'chunk_delay_ms',
    'processingSeconds': 'processing_seconds',
    'artisanName': 'artisan_name',
    'pageSizes': 'page_sizes',
    'uploadPolicy': 'upload_policy',
    'hlsUrl': 'hls_url',
    'uploadUrl': 'upload_url',
    'logEvents': 'log_events',
  },
);

MockPageSizesSchema _$MockPageSizesSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MockPageSizesSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['products', 'logs']);
      final val = MockPageSizesSchema(
        products: $checkedConvert('products', (v) => (v as num).toInt()),
        logs: $checkedConvert('logs', (v) => (v as num).toInt()),
      );
      return val;
    });

MockUploadPolicySchema _$MockUploadPolicySchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'MockUploadPolicySchema',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'max_duration_seconds',
        'allowed_mime_types',
        'chunk_size_bytes',
      ],
    );
    final val = MockUploadPolicySchema(
      maxDurationSeconds: $checkedConvert(
        'max_duration_seconds',
        (v) => (v as num).toInt(),
      ),
      allowedMimeTypes: $checkedConvert(
        'allowed_mime_types',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      chunkSizeBytes: $checkedConvert(
        'chunk_size_bytes',
        (v) => (v as num).toInt(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'maxDurationSeconds': 'max_duration_seconds',
    'allowedMimeTypes': 'allowed_mime_types',
    'chunkSizeBytes': 'chunk_size_bytes',
  },
);

MockLogEventSchema _$MockLogEventSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MockLogEventSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['group', 'level', 'message']);
      final val = MockLogEventSchema(
        group: $checkedConvert('group', (v) => v as String),
        level: $checkedConvert('level', (v) => v as String),
        message: $checkedConvert('message', (v) => v as String),
      );
      return val;
    });

MockVideoSchema _$MockVideoSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MockVideoSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['name', 'size_bytes', 'mime_type', 'seconds'],
      );
      final val = MockVideoSchema(
        name: $checkedConvert('name', (v) => v as String),
        sizeBytes: $checkedConvert('size_bytes', (v) => (v as num).toInt()),
        mimeType: $checkedConvert('mime_type', (v) => v as String),
        seconds: $checkedConvert('seconds', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'sizeBytes': 'size_bytes', 'mimeType': 'mime_type'});

MockProductSchema _$MockProductSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MockProductSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'id',
          'title',
          'artisan',
          'price',
          'tags',
          'status',
          'mine',
          'created_at',
          'description',
        ],
      );
      final val = MockProductSchema(
        id: $checkedConvert('id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        artisan: $checkedConvert('artisan', (v) => v as String),
        price: $checkedConvert('price', (v) => (v as num).toDouble()),
        tags: $checkedConvert(
          'tags',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
        status: $checkedConvert('status', (v) => v as String),
        mine: $checkedConvert('mine', (v) => v as bool? ?? false),
        createdAt: $checkedConvert('created_at', (v) => v as String),
        description: $checkedConvert('description', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'createdAt': 'created_at'});
