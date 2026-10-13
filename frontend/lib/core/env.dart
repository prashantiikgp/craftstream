/// The environment this build was made for (env/<name>.json via --dart-define-from-file).
///
/// Everything here is compiled into the app and readable by anyone, so it is public config only.
/// `AppEnv.validate` enforces the security rules from env/README.md at startup.
library;

import 'package:flutter/foundation.dart';

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
  final String themePalette;
  final String themeMode; // light | dark | system
  final bool devTools;
  final LogLevel logLevel;

  const AppEnv({
    required this.name,
    required this.apiHost,
    required this.themePalette,
    required this.themeMode,
    required this.devTools,
    required this.logLevel,
  });

  bool get isProd => name == AppEnvName.prod;

  /// Values compiled in with --dart-define-from-file. Defaults only apply to debug runs without an env file.
  static const _rawName = String.fromEnvironment('APP_ENV');
  static const _rawApiHost = String.fromEnvironment('API_HOST', defaultValue: 'http://localhost:8000');
  static const _rawPalette = String.fromEnvironment('THEME_PALETTE', defaultValue: 'saffron');
  static const _rawMode = String.fromEnvironment('THEME_MODE', defaultValue: 'system');
  static const _rawDevTools = bool.fromEnvironment('DEV_TOOLS', defaultValue: true);
  static const _rawLogLevel = String.fromEnvironment('LOG_LEVEL', defaultValue: 'debug');

  /// Reads the compiled-in values and validates them. Throws [EnvError] listing every problem.
  static AppEnv fromCompiledValues({bool releaseMode = kReleaseMode}) => parse(
        {
          'APP_ENV': _rawName,
          'API_HOST': _rawApiHost,
          'THEME_PALETTE': _rawPalette,
          'THEME_MODE': _rawMode,
          'DEV_TOOLS': _rawDevTools,
          'LOG_LEVEL': _rawLogLevel,
        },
        releaseMode: releaseMode,
      );

  /// Validates raw values (also used by tests and by the env-file check).
  static AppEnv parse(Map<String, Object?> raw, {bool releaseMode = false}) {
    final problems = <String>[];

    final rawName = (raw['APP_ENV'] as String?) ?? '';
    if (rawName.isEmpty && releaseMode) {
      problems.add('APP_ENV is required in release builds (build with --dart-define-from-file=env/<name>.json)');
    }
    final name = AppEnvName.values.where((e) => e.name == (rawName.isEmpty ? 'dev' : rawName)).firstOrNull;
    if (name == null) problems.add('APP_ENV must be dev, staging or prod, got "$rawName"');

    final host = Uri.tryParse((raw['API_HOST'] as String?) ?? '');
    if (host == null || !host.hasScheme || host.host.isEmpty) {
      problems.add('API_HOST must be an absolute URL, got "${raw['API_HOST']}"');
    } else {
      if (name != AppEnvName.dev && host.scheme != 'https') problems.add('API_HOST must use https outside dev');
      if (host.scheme != 'https' && host.scheme != 'http') problems.add('API_HOST must be http(s)');
      if (host.userInfo.isNotEmpty) problems.add('API_HOST must not contain credentials');
      if ((host.path.isNotEmpty && host.path != '/') || host.hasQuery || host.hasFragment) {
        problems.add('API_HOST must be just scheme://host[:port]');
      }
    }

    final mode = (raw['THEME_MODE'] as String?) ?? '';
    if (!const {'light', 'dark', 'system'}.contains(mode)) problems.add('THEME_MODE must be light, dark or system');

    final palette = (raw['THEME_PALETTE'] as String?) ?? '';
    if (palette.isEmpty) problems.add('THEME_PALETTE is required');

    final devTools = raw['DEV_TOOLS'];
    if (devTools is! bool) problems.add('DEV_TOOLS must be true or false');
    if (name == AppEnvName.prod && devTools == true) problems.add('DEV_TOOLS must be false in prod');

    final level = LogLevel.values.where((l) => l.name == raw['LOG_LEVEL']).firstOrNull;
    if (level == null) problems.add('LOG_LEVEL must be debug, info, warn or error');
    if (name == AppEnvName.prod && level == LogLevel.debug) problems.add('LOG_LEVEL debug is not allowed in prod');

    if (problems.isNotEmpty) throw EnvError(problems);
    return AppEnv(
      name: name!,
      apiHost: host!.replace(path: ''),
      themePalette: palette,
      themeMode: mode,
      devTools: devTools as bool,
      logLevel: level!,
    );
  }

  /// The API base URL as seen from this device. In dev, the Android emulator reaches the host machine's
  /// localhost at 10.0.2.2, so one dev env file works for Chrome and the emulator.
  Uri apiHostFor({required bool isAndroid}) {
    if (name == AppEnvName.dev && isAndroid && apiHost.host == 'localhost') {
      return apiHost.replace(host: '10.0.2.2');
    }
    return apiHost;
  }
}
