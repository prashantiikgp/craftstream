/// The app shell: theme B tokens (light/dark from ThemeChoice) and the router.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/router.dart';
import 'shared/theme/app_theme.dart';

class CraftStreamApp extends ConsumerWidget {
  const CraftStreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final mode = ref.watch(themeChoiceProvider);
    return MaterialApp.router(
      title: 'CraftStream',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(config.theme.light),
      darkTheme: buildTheme(config.theme.dark),
      themeMode: mode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
