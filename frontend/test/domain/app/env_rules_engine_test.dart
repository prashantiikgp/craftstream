import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/app/env_rules_engine.dart';
import 'package:craftstream/schemas/app/env_rules_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/app/env_rules.yml';
EnvRulesSchema rules([String Function(String)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, EnvRulesSchema.fromJson);
}

void main() {
  final engine = EnvRulesEngine(rules());

  List<String> check(String env, {String scheme = 'https', bool dev = false, bool mock = false, bool debug = false}) =>
      engine.problems(env: env, apiScheme: scheme, devTools: dev, mockData: mock, debugLogs: debug);

  test('env_rules.yml loads: three environments, debug runs default to dev', () {
    expect(engine.names, ['dev', 'staging', 'prod']);
    expect(engine.debugDefault('APP_ENV'), 'dev');
    expect(engine.debugDefault('API_HOST'), 'http://localhost:8000');
    expect(engine.debugDefault('MOCK_DATA'), isTrue);
  });

  test('https everywhere but dev', () {
    expect(check('dev', scheme: 'http'), isEmpty);
    expect(check('staging', scheme: 'http'), [contains('https')]);
    expect(check('prod', scheme: 'http'), [contains('https')]);
  });

  test('prod ships no dev tools, mock data or debug logging; the others may', () {
    expect(check('prod', dev: true, mock: true, debug: true), hasLength(3));
    expect(check('staging', dev: true, mock: true, debug: true), isEmpty);
    expect(check('dev', scheme: 'http', dev: true, mock: true, debug: true), isEmpty);
  });

  test('an environment env_rules.yml does not know is a problem, not a pass', () {
    expect(check('qa'), [contains('no rules')]);
  });

  test('the Android emulator reaches the dev host machine as 10.0.2.2', () {
    expect(engine.hostFor('dev', 'localhost', isAndroid: true), '10.0.2.2');
    expect(engine.hostFor('dev', 'localhost', isAndroid: false), 'localhost');
    expect(engine.hostFor('dev', 'api.example.com', isAndroid: true), 'api.example.com');
    expect(engine.hostFor('prod', 'localhost', isAndroid: true), 'localhost');
  });

  test('bad files are rejected', () {
    expect(
      () => EnvRulesEngine(rules((t) => t.replaceFirst('APP_ENV: dev', 'APP_ENV: local'))),
      throwsA(isA<EnvRulesError>()),
    );
    expect(() => rules((t) => t.replaceFirst('require_https: true', 'require_tls: true')), throwsA(isA<ConfigError>()));
  });
}
