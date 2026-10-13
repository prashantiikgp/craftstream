/// Startup: validate the environment and every YAML rule file, then run the app.
/// If anything is wrong, show what and stop: the app never runs with half its config.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/config_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = await loadAppConfig();
    runApp(ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const CraftStreamApp(),
    ));
  } catch (e) {
    runApp(ConfigErrorApp(error: e));
  }
}
