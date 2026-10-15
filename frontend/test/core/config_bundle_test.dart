// The hosted web app reads every rule file from one bundle (tools/web_bundle.py, core/config_bundle.dart). The
// whole config must load from it alone, rule folders included, and match what the separate files give.
import 'dart:io';

import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/config_bundle.dart';
import 'package:craftstream/core/env.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

/// Fails the test if a loader reaches past the bundle.
class _NoAssets extends AssetBundle {
  @override
  Future<ByteData> load(String key) => throw StateError('read $key outside the bundle');
  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) =>
      throw StateError('read $key outside the bundle');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // What tools/web_bundle.py writes: {asset key: text} for every rule YAML.
  final files = {
    for (final f in Directory('assets/config').listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.yml')) f.path.replaceAll(r'\', '/'): f.readAsStringSync(),
  };

  test('the whole config loads from the bundle alone', () async {
    final env = AppEnv.parse(testEnvValues());
    final bundled = await loadAppConfig(env: env, bundle: ConfigBundle(files, fallback: _NoAssets()));
    final separate = await loadAppConfig(env: env);
    expect(bundled.screens.names, separate.screens.names);
    expect(bundled.strings.get('home.buy_title'), separate.strings.get('home.buy_title'));
  });

  test('a rule folder is listed from the bundle, sorted', () {
    final b = ConfigBundle(files, fallback: _NoAssets());
    final screens = b.keysUnder('assets/config/ui/screens/');
    expect(screens, contains('assets/config/ui/screens/home.yml'));
    expect(screens, orderedEquals([...screens]..sort()));
  });

  test('anything not in the bundle comes from the fallback', () async {
    final b = ConfigBundle(const {'assets/config/a.yml': 'x: ₹1'}, fallback: _NoAssets());
    expect(await b.loadString('assets/config/a.yml'), 'x: ₹1');
    expect(() => b.loadString('assets/fonts/x.ttf'), throwsStateError);
  });
}
