import 'package:craftstream/core/env.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> base([Map<String, Object?> changes = const {}]) => {
      'APP_ENV': 'prod',
      'API_HOST': 'https://api.example.com',
      'THEME_PALETTE': 'saffron',
      'THEME_MODE': 'light',
      'DEV_TOOLS': false,
      'LOG_LEVEL': 'warn',
      ...changes,
    };

void expectRejected(Map<String, Object?> raw, String fragment, {bool releaseMode = false}) {
  expect(
    () => AppEnv.parse(raw, releaseMode: releaseMode),
    throwsA(isA<EnvError>().having((e) => e.toString(), 'message', contains(fragment))),
  );
}

void main() {
  test('a valid prod env parses', () {
    final env = AppEnv.parse(base());
    expect(env.isProd, isTrue);
    expect(env.apiHost.toString(), 'https://api.example.com');
  });

  test('prod and staging need https', () {
    expectRejected(base({'API_HOST': 'http://api.example.com'}), 'https');
    expectRejected(base({'APP_ENV': 'staging', 'API_HOST': 'http://api.example.com'}), 'https');
    expect(AppEnv.parse(base({'APP_ENV': 'dev', 'API_HOST': 'http://localhost:8000', 'DEV_TOOLS': true})).name,
        AppEnvName.dev);
  });

  test('prod cannot ship dev tools or debug logging', () {
    expectRejected(base({'DEV_TOOLS': true}), 'DEV_TOOLS must be false in prod');
    expectRejected(base({'LOG_LEVEL': 'debug'}), 'debug is not allowed in prod');
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
      AppEnv.parse(base({'API_HOST': 'http://x.com', 'DEV_TOOLS': true, 'THEME_MODE': 'neon'}));
      fail('should throw');
    } on EnvError catch (e) {
      expect(e.problems.length, greaterThanOrEqualTo(3));
    }
  });

  test('dev on the Android emulator reaches the host machine', () {
    final env = AppEnv.parse(base({'APP_ENV': 'dev', 'API_HOST': 'http://localhost:8000', 'DEV_TOOLS': true}));
    expect(env.apiHostFor(isAndroid: true).toString(), 'http://10.0.2.2:8000');
    expect(env.apiHostFor(isAndroid: false).toString(), 'http://localhost:8000');
  });
}
