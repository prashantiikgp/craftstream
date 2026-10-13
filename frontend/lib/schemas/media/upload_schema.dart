/// Shape of assets/config/media/upload.yml: retry and polling behaviour of the uploader.
library;

import 'package:json_annotation/json_annotation.dart';

part 'upload_schema.g.dart';

@JsonSerializable()
class UploadSchema {
  final List<int> retryBackoffSeconds;
  final int maxRetries;
  final int statusPollSeconds;
  final int statusPollTimeoutMinutes;

  const UploadSchema({
    required this.retryBackoffSeconds,
    required this.maxRetries,
    required this.statusPollSeconds,
    required this.statusPollTimeoutMinutes,
  });

  factory UploadSchema.fromJson(Map<String, dynamic> json) => _$UploadSchemaFromJson(json);
}
