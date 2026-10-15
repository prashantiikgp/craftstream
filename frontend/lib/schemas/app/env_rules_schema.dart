/// Shape of assets/config/app/env_rules.yml: what each environment may do, and the debug-run defaults.
library;

import 'package:json_annotation/json_annotation.dart';

part 'env_rules_schema.g.dart';

@JsonSerializable()
class EnvRulesSchema {
  /// Env file key -> value for a debug run without an env file.
  final Map<String, Object> debugDefaults;
  final Map<String, EnvironmentRulesSchema> environments;

  const EnvRulesSchema({required this.debugDefaults, required this.environments});

  factory EnvRulesSchema.fromJson(Map<String, dynamic> json) => _$EnvRulesSchemaFromJson(json);
}

@JsonSerializable()
class EnvironmentRulesSchema {
  final bool requireHttps;
  final bool allowDevTools;
  final bool allowMockData;
  final bool allowDebugLogs;

  /// API_HOST host name -> the name the Android emulator reaches it by.
  final Map<String, String> androidHosts;

  const EnvironmentRulesSchema({
    required this.requireHttps,
    required this.allowDevTools,
    required this.allowMockData,
    required this.allowDebugLogs,
    this.androidHosts = const {},
  });

  factory EnvironmentRulesSchema.fromJson(Map<String, dynamic> json) => _$EnvironmentRulesSchemaFromJson(json);
}
