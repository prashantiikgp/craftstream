// Every env/*.json is compiled into the shipped app, so it must hold public settings only and pass AppEnv rules.
import 'dart:convert';
import 'dart:io';

import 'package:craftstream/core/env.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

const allowedKeys = {'APP_ENV', 'API_HOST', 'DEV_TOOLS', 'MOCK_DATA', 'LOG_LEVEL'};
final secretLooking = RegExp(r'KEY|SECRET|TOKEN|PASSWORD|PASSWD|CREDENTIAL|PRIVATE', caseSensitive: false);

void main() {
  final rules = testEnvRules();
  final files = Directory('env').listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();

  test('there is an env file for each environment', () {
    final names = files.map((f) => f.uri.pathSegments.last).toSet();
    expect(names, containsAll(['dev.json', 'staging.json', 'prod.json']));
    expect(AppEnv.keys.toSet(), allowedKeys, reason: 'AppEnv reads exactly the allowed keys');
    expect(rules.names.map((n) => '$n.json'), unorderedEquals(names), reason: 'env_rules.yml has rules for each');
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    test('$name has only known, non-secret keys', () {
      expect(raw.keys.where(secretLooking.hasMatch), isEmpty, reason: 'secrets never go in the app');
      expect(raw.keys.toSet().difference(allowedKeys), isEmpty, reason: 'add new keys to AppEnv and env/README.md');
      expect(allowedKeys.difference(raw.keys.toSet()), isEmpty, reason: 'every key must be set explicitly');
    });

    test('$name passes the AppEnv rules as a release build', () {
      final env = AppEnv.parse(raw, rules: rules, releaseMode: true);
      expect(name, '${env.name.name}.json');
    });
  }
}
