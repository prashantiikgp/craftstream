/// The environment this build was made for (env/<name>.json via --dart-define-from-file).
///
/// Everything here is compiled into the app and readable by anyone, so it is public config only.
/// `AppEnv.parse` checks each value's shape here and the environment policy from app/env_rules.yml
/// (EnvRulesEngine: https, dev tools, mock data, debug logs, the Android dev host) at startup.
library;

import 'package:flutter/foundation.dart';

import '../domain/app/env_rules_engine.dart';

enum AppEnvName { dev, staging, prod }

enum LogLevel { debug, info, warn, error }

class EnvError implements Exception {
  final List<String> problems;
  const EnvError(this.problems);
  @override
  String toString() => 'Invalid environment:\n- ${problems.join('\n- ')}';
}

class AppEnv {
  final AppEnvName name;
  final Uri apiHost;
  final String themeMode; // light | dark | system
  final bool devTools;
  final bool mockData; // true = in-app fake data, no API calls (lib/data/mock/)
  final LogLevel logLevel;

  const AppEnv({
    required this.name,
    required this.apiHost,
    required this.themeMode,
    required this.devTools,
    required this.mockData,
    required this.logLevel,
  });

  bool get isProd => name == AppEnvName.prod;

  /// The env file keys.
  static const keys = ['APP_ENV', 'API_HOST', 'THEME_MODE', 'DEV_TOOLS', 'MOCK_DATA', 'LOG_LEVEL'];

  /// Values compiled in with --dart-define-from-file, and whether each was given at all.
  static const _compiled = <String, (bool, Object)>{
    'APP_ENV': (bool.hasEnvironment('APP_ENV'), String.fromEnvironment('APP_ENV')),
    'API_HOST': (bool.hasEnvironment('API_HOST'), String.fromEnvironment('API_HOST')),
    'THEME_MODE': (bool.hasEnvironment('THEME_MODE'), String.fromEnvironment('THEME_MODE')),
    'DEV_TOOLS': (bool.hasEnvironment('DEV_TOOLS'), bool.fromEnvironment('DEV_TOOLS')),
    'MOCK_DATA': (bool.hasEnvironment('MOCK_DATA'), bool.fromEnvironment('MOCK_DATA')),
    'LOG_LEVEL': (bool.hasEnvironment('LOG_LEVEL'), String.fromEnvironment('LOG_LEVEL')),
  };

  /// Reads the compiled-in values and validates them. A key the build did not set takes env_rules.yml's
  /// `debug_defaults` value, except APP_ENV in a release build (it must be named). Throws [EnvError].
  static AppEnv fromCompiledValues(EnvRulesEngine rules, {bool releaseMode = kReleaseMode}) => parse(
    {
      for (final MapEntry(key: key, value: (given, value)) in _compiled.entries)
        key: given || (releaseMode && key == EnvRulesEngine.envKey) ? value : rules.debugDefault(key),
    },
    rules: rules,
    releaseMode: releaseMode,
  );

  /// Validates raw values (also used by tests and by the env-file check): their shape, then [rules]' policy for
  /// the environment they name. Every problem is reported at once.
  static AppEnv parse(Map<String, Object?> raw, {required EnvRulesEngine rules, bool releaseMode = false}) {
    final problems = <String>[
      for (final key in rules.debugDefaultKeys)
        if (!keys.contains(key)) 'env_rules.yml debug_defaults: "$key" is not an env file key',
    ];

    final rawName = (raw['APP_ENV'] as String?) ?? '';
    if (rawName.isEmpty && releaseMode) {
      problems.add('APP_ENV is required in release builds (build with --dart-define-from-file=env/<name>.json)');
    }
    final name = AppEnvName.values.where((e) => e.name == rawName).firstOrNull;
    if (name == null && rawName.isNotEmpty) problems.add('APP_ENV must be dev, staging or prod, got "$rawName"');
    if (name == null && rawName.isEmpty && !releaseMode) problems.add('APP_ENV is empty');

    final host = Uri.tryParse((raw['API_HOST'] as String?) ?? '');
    if (host == null || !host.hasScheme || host.host.isEmpty) {
      problems.add('API_HOST must be an absolute URL, got "${raw['API_HOST']}"');
    } else {
      if (host.scheme != 'https' && host.scheme != 'http') problems.add('API_HOST must be http(s)');
      if (host.userInfo.isNotEmpty) problems.add('API_HOST must not contain credentials');
      if ((host.path.isNotEmpty && host.path != '/') || host.hasQuery || host.hasFragment) {
        problems.add('API_HOST must be just scheme://host[:port]');
      }
    }

    final mode = (raw['THEME_MODE'] as String?) ?? '';
    if (!const {'light', 'dark', 'system'}.contains(mode)) problems.add('THEME_MODE must be light, dark or system');

    final devTools = raw['DEV_TOOLS'];
    if (devTools is! bool) problems.add('DEV_TOOLS must be true or false');

    final mockData = raw['MOCK_DATA'];
    if (mockData is! bool) problems.add('MOCK_DATA must be true or false');

    final level = LogLevel.values.where((l) => l.name == raw['LOG_LEVEL']).firstOrNull;
    if (level == null) problems.add('LOG_LEVEL must be debug, info, warn or error');

    if (name != null) {
      problems.addAll(
        rules.problems(
          env: name.name,
          apiScheme: host?.scheme ?? '',
          devTools: devTools == true,
          mockData: mockData == true,
          debugLogs: level == LogLevel.debug,
        ),
      );
    }

    if (problems.isNotEmpty) throw EnvError(problems);
    return AppEnv(
      name: name!,
      apiHost: host!.replace(path: ''),
      themeMode: mode,
      devTools: devTools as bool,
      mockData: mockData as bool,
      logLevel: level!,
    );
  }

  /// This env, after checking it against [rules]' policy (for an env parsed elsewhere, e.g. in tests).
  AppEnv checkedBy(EnvRulesEngine rules) {
    final problems = rules.problems(
      env: name.name,
      apiScheme: apiHost.scheme,
      devTools: devTools,
      mockData: mockData,
      debugLogs: logLevel == LogLevel.debug,
    );
    if (problems.isNotEmpty) throw EnvError(problems);
    return this;
  }

  /// The API base URL as seen from this device (env_rules.yml `android_hosts`: in dev the Android emulator
  /// reaches the host machine's localhost at 10.0.2.2, so one dev env file works for Chrome and the emulator).
  Uri apiHostFor(EnvRulesEngine rules, {required bool isAndroid}) =>
      apiHost.replace(host: rules.hostFor(name.name, apiHost.host, isAndroid: isAndroid));
}
