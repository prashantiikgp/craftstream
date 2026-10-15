/// On the hosted web app every rule YAML arrives in one file, `config.<hash>.json`, written by
/// `tools/web_bundle.py` after `flutter build web`: one request instead of one per file, and a content-hashed
/// name the browser may cache for good. [loadConfigBundle] finds it (web only); [ConfigBundle] serves its files
/// to the loaders under their usual asset keys. Everywhere else (Android, tests, `make web`) nothing changes.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

export 'config_bundle_stub.dart' if (dart.library.js_interop) 'config_bundle_web.dart';

/// The rule files, keyed by asset key (`assets/config/ui/theme.yml`). Anything else comes from [fallback].
class ConfigBundle extends CachingAssetBundle {
  final Map<String, String> files;
  final AssetBundle fallback;
  ConfigBundle(this.files, {AssetBundle? fallback}) : fallback = fallback ?? rootBundle;

  /// Reads the bundle's JSON (`{asset key: file text}`).
  factory ConfigBundle.fromJson(String json, {AssetBundle? fallback}) =>
      ConfigBundle((jsonDecode(json) as Map).cast<String, String>(), fallback: fallback);

  /// The bundled files under [prefix], sorted, so a rule folder is read without the asset manifest.
  List<String> keysUnder(String prefix) => files.keys.where((k) => k.startsWith(prefix)).toList()..sort();

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    return text == null ? fallback.load(key) : ByteData.sublistView(utf8.encode(text));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      files[key] ?? fallback.loadString(key, cache: cache);
}
