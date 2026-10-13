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
        );
        return val;
      },
      fieldKeyMap: const {
        'retryBackoffSeconds': 'retry_backoff_seconds',
        'maxRetries': 'max_retries',
        'statusPollSeconds': 'status_poll_seconds',
        'statusPollTimeoutMinutes': 'status_poll_timeout_minutes',
      },
    );
