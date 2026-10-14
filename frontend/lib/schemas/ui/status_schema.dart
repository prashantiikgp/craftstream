/// Shape of assets/config/ui/status.yml: how each video and order status looks.
library;

import 'package:json_annotation/json_annotation.dart';

part 'status_schema.g.dart';

@JsonSerializable()
class StatusSchema {
  final Map<String, StatusLookSchema> video;
  final Map<String, StatusLookSchema> order;

  const StatusSchema({required this.video, required this.order});

  factory StatusSchema.fromJson(Map<String, dynamic> json) => _$StatusSchemaFromJson(json);
}

@JsonSerializable()
class StatusLookSchema {
  final String label;
  final String tone;
  final String? hint;
  final bool progress;
  final bool retry;

  const StatusLookSchema({required this.label, required this.tone, this.hint, this.progress = false, this.retry = false});

  factory StatusLookSchema.fromJson(Map<String, dynamic> json) => _$StatusLookSchemaFromJson(json);
}
