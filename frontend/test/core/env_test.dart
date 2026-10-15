import 'package:craftstream/core/env.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

final rules = testEnvRules();

Map<String, Object?> base([Map<String, Object?> changes = const {}]) => {
  'APP_ENV': 'prod',
  'API_HOST': 'https://api.example.com',
  'THEME_MODE': 'light',
  'DEV_TOOLS': false,
  'MOCK_DATA': false,
  'LOG_LEVEL': 'warn',
  ...changes,
};

void expectRejected(Map<String, Object?> raw, String fragment, {bool releaseMode = false}) {
  expect(
    () => AppEnv.parse(raw, rules: rules, releaseMode: releaseMode),
    throwsA(isA<EnvError>().having((e) => e.toString(), 'message', contains(fragment))),
  );
}

void main() {
  test('a valid prod env parses', () {
    final env = AppEnv.parse(base(), rules: rules);
    expect(env.isProd, isTrue);
    expect(env.apiHost.toString(), 'https://api.example.com');
  });

  test('prod and staging need https', () {
    expectRejected(base({'API_HOST': 'http://api.example.com'}), 'https');
    expectRejected(base({'APP_ENV': 'staging', 'API_HOST': 'http://api.example.com'}), 'https');
    expect(
      AppEnv.parse(base({'APP_ENV': 'dev', 'API_HOST': 'http://localhost:8000', 'DEV_TOOLS': true}), rules: rules).name,
      AppEnvName.dev,
    );
  });

  test('prod cannot ship dev tools or debug logging', () {
    expectRejected(base({'DEV_TOOLS': true}), 'DEV_TOOLS must be false in prod');
    expectRejected(base({'LOG_LEVEL': 'debug'}), 'debug is not allowed in prod');
    expectRejected(base({'MOCK_DATA': true}), 'MOCK_DATA must be false in prod');
  });

  test('API_HOST must be a bare origin without credentials', () {
    expectRejected(base({'API_HOST': 'https://user:pw@api.example.com'}), 'credentials');
    expectRejected(base({'API_HOST': 'https://api.example.com/v1?key=1'}), 'scheme://host');
    expectRejected(base({'API_HOST': 'not a url'}), 'absolute URL');
  });

  test('release builds must say which environment they are', () {
    expectRejected(base({'APP_ENV': ''}), 'required in release builds', releaseMode: true);
  });

  test('every problem is reported at once', () {
    try {
      AppEnv.parse(base({'API_HOST': 'http://x.com', 'DEV_TOOLS': true, 'THEME_MODE': 'neon'}), rules: rules);
      fail('should throw');
    } on EnvError catch (e) {
      expect(e.problems.length, greaterThanOrEqualTo(3));
    }
  });

  test('dev on the Android emulator reaches the host machine', () {
    final env = AppEnv.parse(
      base({'APP_ENV': 'dev', 'API_HOST': 'http://localhost:8000', 'DEV_TOOLS': true}),
      rules: rules,
    );
    expect(env.apiHostFor(rules, isAndroid: true).toString(), 'http://10.0.2.2:8000');
    expect(env.apiHostFor(rules, isAndroid: false).toString(), 'http://localhost:8000');
    // Outside dev the host is used as given, even on Android.
    expect(AppEnv.parse(base(), rules: rules).apiHostFor(rules, isAndroid: true).toString(), 'https://api.example.com');
  });

  test('an env parsed elsewhere still has to pass the policy', () {
    final dev = AppEnv.parse(base({'APP_ENV': 'dev', 'LOG_LEVEL': 'debug'}), rules: rules);
    expect(dev.checkedBy(rules), same(dev));
    final prodWithDebug = AppEnv(
      name: AppEnvName.prod,
      apiHost: Uri.parse('https://api.example.com'),
      themeMode: 'light',
      devTools: false,
      mockData: false,
      logLevel: LogLevel.debug,
    );
    expect(() => prodWithDebug.checkedBy(rules), throwsA(isA<EnvError>()));
  });

  test('a debug run without an env file uses env_rules.yml debug_defaults', () {
    final env = AppEnv.fromCompiledValues(rules, releaseMode: false);
    expect(env.name, AppEnvName.dev);
    expect(env.apiHost.toString(), 'http://localhost:8000');
    expect(env.mockData, isTrue);
    expectRejected(const {}, 'required in release builds', releaseMode: true);
  });
}
