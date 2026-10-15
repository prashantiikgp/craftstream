// The browser: index.html names the bundle in a <meta> (tools/web_bundle.py adds it). Without the tag
// (`make web`, `flutter run`) or if the fetch fails, the rule files are read one by one as before.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'config_bundle.dart';

/// The <meta name> tools/web_bundle.py writes; keep the two in step.
const bundleMetaName = 'craftstream-config';

Future<AssetBundle?> loadConfigBundle() async {
  final name = web.document.querySelector('meta[name="$bundleMetaName"]')?.getAttribute('content');
  if (name == null) return null;
  try {
    final res = await http.get(Uri.parse(web.document.baseURI).resolve(name));
    return res.statusCode == 200 ? ConfigBundle.fromJson(utf8.decode(res.bodyBytes)) : null;
  } catch (_) {
    return null;
  }
}
