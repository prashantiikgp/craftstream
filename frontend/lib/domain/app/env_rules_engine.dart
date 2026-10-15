/// The environment policy from env_rules.yml. Pure Dart over plain values: lib/core/env.dart parses the compiled-in
/// env values and asks this engine whether they are allowed where they are.
library;

import '../../schemas/app/env_rules_schema.dart';

class EnvRulesError implements Exception {
  final String message;
  const EnvRulesError(this.message);
  @override
  String toString() => 'env_rules.yml: $message';
}

class EnvRulesEngine {
  /// The env file key that names the environment.
  static const envKey = 'APP_ENV';

  final EnvRulesSchema rules;

  EnvRulesEngine(this.rules) {
    if (rules.environments.isEmpty) throw const EnvRulesError('environments must not be empty');
    final fallback = rules.debugDefaults[envKey];
    if (fallback is! String || !rules.environments.containsKey(fallback)) {
      throw const EnvRulesError('debug_defaults.$envKey must name one of the environments');
    }
    for (final MapEntry(key: name, value: e) in rules.environments.entries) {
      if (e.androidHosts.entries.any((h) => h.key.isEmpty || h.value.isEmpty)) {
        throw EnvRulesError('environments.$name.android_hosts: host names must not be empty');
      }
    }
  }

  /// Every environment name, as APP_ENV writes it.
  Iterable<String> get names => rules.environments.keys;

  /// The value a debug run without an env file uses for [key] (null when there is none).
  Object? debugDefault(String key) => rules.debugDefaults[key];

  Iterable<String> get debugDefaultKeys => rules.debugDefaults.keys;

  /// What is wrong with these values in environment [env] (empty when they are allowed). Messages name the env
  /// file key, so they read like the env file.
  List<String> problems({
    required String env,
    required String apiScheme,
    required bool devTools,
    required bool mockData,
    required bool debugLogs,
  }) {
    final e = rules.environments[env];
    if (e == null) return ['env_rules.yml has no rules for APP_ENV "$env"'];
    return [
      if (e.requireHttps && apiScheme != 'https') 'API_HOST must use https in $env',
      if (!e.allowDevTools && devTools) 'DEV_TOOLS must be false in $env',
      if (!e.allowMockData && mockData) 'MOCK_DATA must be false in $env',
      if (!e.allowDebugLogs && debugLogs) 'LOG_LEVEL debug is not allowed in $env',
    ];
  }

  /// The API host name as this device reaches it: in an environment with `android_hosts`, the Android emulator
  /// reaches the host machine under another name.
  String hostFor(String env, String host, {required bool isAndroid}) =>
      isAndroid ? rules.environments[env]?.androidHosts[host] ?? host : host;
}
