/// The app shell: theme from tokens (palette + light/dark from ThemeChoice) and the router.
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
    final choice = ref.watch(themeChoiceProvider);
    return MaterialApp.router(
      title: 'CraftStream',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(config.theme.resolve(choice.palette, Brightness.light)),
      darkTheme: buildTheme(config.theme.resolve(choice.palette, Brightness.dark)),
      themeMode: choice.mode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
