/// Startup: validate the environment and every YAML rule file, then run the app.
/// If anything is wrong, show what and stop: the app never runs with half its config.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/config_bundle.dart';
import 'core/config_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // On the hosted web app the rule files come in one bundle (core/config_bundle.dart).
    final config = await loadAppConfig(bundle: await loadConfigBundle());
    runApp(ProviderScope(
      // Screens show errors with a Retry button; repositories own any retrying, so providers never auto-retry.
      retry: (_, _) => null,
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const CraftStreamApp(),
    ));
  } catch (e) {
    runApp(ConfigErrorApp(error: e));
  }
}
