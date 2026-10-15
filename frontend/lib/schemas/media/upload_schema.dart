/// Shape of assets/config/media/upload.yml: retry and polling behaviour of the uploader, what the upload
/// session's HTTP answers mean, picking the video, and the listing form's tag and price rules.
library;

import 'package:json_annotation/json_annotation.dart';

part 'upload_schema.g.dart';

@JsonSerializable()
class UploadSchema {
  final List<int> retryBackoffSeconds;
  final int maxRetries;
  final int statusPollSeconds;
  final int statusPollTimeoutMinutes;
  final UploadHttpStatusSchema httpStatus;
  final PickerSchema picker;
  final TagRulesSchema tags;
  final PriceRulesSchema price;

  const UploadSchema({
    required this.retryBackoffSeconds,
    required this.maxRetries,
    required this.statusPollSeconds,
    required this.statusPollTimeoutMinutes,
    required this.httpStatus,
    required this.picker,
    required this.tags,
    required this.price,
  });

  factory UploadSchema.fromJson(Map<String, dynamic> json) => _$UploadSchemaFromJson(json);
}

/// Each entry is a status code (`308`) or a class (`5xx`).
@JsonSerializable()
class UploadHttpStatusSchema {
  final List<Object> done;
  @JsonKey(name: 'continue')
  final List<Object> more;
  final List<Object> retry;

  const UploadHttpStatusSchema({required this.done, required this.more, required this.retry});

  factory UploadHttpStatusSchema.fromJson(Map<String, dynamic> json) => _$UploadHttpStatusSchemaFromJson(json);
}

@JsonSerializable()
class PickerSchema {
  final String accept;
  final int metadataTimeoutSeconds;

  /// Lower-case file extension -> MIME type.
  final Map<String, String> mimeTypes;
  final String defaultMimeType;

  const PickerSchema({
    required this.accept,
    required this.metadataTimeoutSeconds,
    required this.mimeTypes,
    required this.defaultMimeType,
  });

  factory PickerSchema.fromJson(Map<String, dynamic> json) => _$PickerSchemaFromJson(json);
}

@JsonSerializable()
class TagRulesSchema {
  final String separator;
  final bool lowerCase;

  const TagRulesSchema({required this.separator, required this.lowerCase});

  factory TagRulesSchema.fromJson(Map<String, dynamic> json) => _$TagRulesSchemaFromJson(json);
}

@JsonSerializable()
class PriceRulesSchema {
  /// Characters dropped before the number is read.
  final List<String> ignore;
  final String currency;

  const PriceRulesSchema({required this.ignore, required this.currency});

  factory PriceRulesSchema.fromJson(Map<String, dynamic> json) => _$PriceRulesSchemaFromJson(json);
}
