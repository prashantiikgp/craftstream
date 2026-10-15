// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadSchema _$UploadSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'UploadSchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'retry_backoff_seconds',
            'max_retries',
            'status_poll_seconds',
            'status_poll_timeout_minutes',
            'http_status',
            'picker',
            'tags',
            'price',
          ],
        );
        final val = UploadSchema(
          retryBackoffSeconds: $checkedConvert(
            'retry_backoff_seconds',
            (v) => (v as List<dynamic>).map((e) => (e as num).toInt()).toList(),
          ),
          maxRetries: $checkedConvert('max_retries', (v) => (v as num).toInt()),
          statusPollSeconds: $checkedConvert(
            'status_poll_seconds',
            (v) => (v as num).toInt(),
          ),
          statusPollTimeoutMinutes: $checkedConvert(
            'status_poll_timeout_minutes',
            (v) => (v as num).toInt(),
          ),
          httpStatus: $checkedConvert(
            'http_status',
            (v) => UploadHttpStatusSchema.fromJson(v as Map<String, dynamic>),
          ),
          picker: $checkedConvert(
            'picker',
            (v) => PickerSchema.fromJson(v as Map<String, dynamic>),
          ),
          tags: $checkedConvert(
            'tags',
            (v) => TagRulesSchema.fromJson(v as Map<String, dynamic>),
          ),
          price: $checkedConvert(
            'price',
            (v) => PriceRulesSchema.fromJson(v as Map<String, dynamic>),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'retryBackoffSeconds': 'retry_backoff_seconds',
        'maxRetries': 'max_retries',
        'statusPollSeconds': 'status_poll_seconds',
        'statusPollTimeoutMinutes': 'status_poll_timeout_minutes',
        'httpStatus': 'http_status',
      },
    );

UploadHttpStatusSchema _$UploadHttpStatusSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('UploadHttpStatusSchema', json, ($checkedConvert) {
  $checkKeys(json, allowedKeys: const ['done', 'continue', 'retry']);
  final val = UploadHttpStatusSchema(
    done: $checkedConvert(
      'done',
      (v) => (v as List<dynamic>).map((e) => e as Object).toList(),
    ),
    more: $checkedConvert(
      'continue',
      (v) => (v as List<dynamic>).map((e) => e as Object).toList(),
    ),
    retry: $checkedConvert(
      'retry',
      (v) => (v as List<dynamic>).map((e) => e as Object).toList(),
    ),
  );
  return val;
}, fieldKeyMap: const {'more': 'continue'});

PickerSchema _$PickerSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PickerSchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'accept',
            'metadata_timeout_seconds',
            'mime_types',
            'default_mime_type',
          ],
        );
        final val = PickerSchema(
          accept: $checkedConvert('accept', (v) => v as String),
          metadataTimeoutSeconds: $checkedConvert(
            'metadata_timeout_seconds',
            (v) => (v as num).toInt(),
          ),
          mimeTypes: $checkedConvert(
            'mime_types',
            (v) => Map<String, String>.from(v as Map),
          ),
          defaultMimeType: $checkedConvert(
            'default_mime_type',
            (v) => v as String,
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'metadataTimeoutSeconds': 'metadata_timeout_seconds',
        'mimeTypes': 'mime_types',
        'defaultMimeType': 'default_mime_type',
      },
    );

TagRulesSchema _$TagRulesSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TagRulesSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['separator', 'lower_case']);
      final val = TagRulesSchema(
        separator: $checkedConvert('separator', (v) => v as String),
        lowerCase: $checkedConvert('lower_case', (v) => v as bool),
      );
      return val;
    }, fieldKeyMap: const {'lowerCase': 'lower_case'});

PriceRulesSchema _$PriceRulesSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PriceRulesSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['ignore', 'currency']);
      final val = PriceRulesSchema(
        ignore: $checkedConvert(
          'ignore',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
        currency: $checkedConvert('currency', (v) => v as String),
      );
      return val;
    });
