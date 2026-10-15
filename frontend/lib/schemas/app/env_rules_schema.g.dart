// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env_rules_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EnvRulesSchema _$EnvRulesSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EnvRulesSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['debug_defaults', 'environments']);
      final val = EnvRulesSchema(
        debugDefaults: $checkedConvert(
          'debug_defaults',
          (v) => (v as Map<String, dynamic>).map(
            (k, e) => MapEntry(k, e as Object),
          ),
        ),
        environments: $checkedConvert(
          'environments',
          (v) => (v as Map<String, dynamic>).map(
            (k, e) => MapEntry(
              k,
              EnvironmentRulesSchema.fromJson(e as Map<String, dynamic>),
            ),
          ),
        ),
      );
      return val;
    }, fieldKeyMap: const {'debugDefaults': 'debug_defaults'});

EnvironmentRulesSchema _$EnvironmentRulesSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'EnvironmentRulesSchema',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'require_https',
        'allow_dev_tools',
        'allow_mock_data',
        'allow_debug_logs',
        'android_hosts',
      ],
    );
    final val = EnvironmentRulesSchema(
      requireHttps: $checkedConvert('require_https', (v) => v as bool),
      allowDevTools: $checkedConvert('allow_dev_tools', (v) => v as bool),
      allowMockData: $checkedConvert('allow_mock_data', (v) => v as bool),
      allowDebugLogs: $checkedConvert('allow_debug_logs', (v) => v as bool),
      androidHosts: $checkedConvert(
        'android_hosts',
        (v) =>
            (v as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(k, e as String),
            ) ??
            const {},
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'requireHttps': 'require_https',
    'allowDevTools': 'allow_dev_tools',
    'allowMockData': 'allow_mock_data',
    'allowDebugLogs': 'allow_debug_logs',
    'androidHosts': 'android_hosts',
  },
);
