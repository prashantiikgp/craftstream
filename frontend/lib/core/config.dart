/// Everything loaded and validated at startup: the environment and the rule engines.
/// If any part fails, main.dart shows ConfigErrorApp instead of running with half the config.
library;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ui/layout_engine.dart';
import '../domain/ui/layout_loader.dart';
import '../domain/ui/theme_engine.dart';
import '../domain/ui/theme_loader.dart';
import 'env.dart';

class AppConfig {
  final AppEnv env;
  final ThemeEngine theme;
  final LayoutEngine layout;
  const AppConfig({required this.env, required this.theme, required this.layout});
}

Future<AppConfig> loadAppConfig({AppEnv? env, AssetBundle? bundle}) async {
  final e = env ?? AppEnv.fromCompiledValues();
  final theme = ThemeEngine(await loadThemeRules(bundle: bundle));
  if (!theme.paletteNames.contains(e.themePalette)) {
    throw EnvError(['THEME_PALETTE "${e.themePalette}" is not in theme.yml (have: ${theme.paletteNames.join(', ')})']);
  }
  final layout = LayoutEngine(await loadLayoutRules(bundle: bundle));
  return AppConfig(env: e, theme: theme, layout: layout);
}

/// Overridden in main.dart with the loaded config.
final appConfigProvider = Provider<AppConfig>((ref) => throw StateError('appConfigProvider not initialised'));

/// Which palette and brightness the app shows. Starts from the environment; changeable only with DEV_TOOLS.
class ThemeChoice {
  final String palette;
  final ThemeMode mode;
  const ThemeChoice(this.palette, this.mode);
}

class ThemeChoiceController extends Notifier<ThemeChoice> {
  @override
  ThemeChoice build() {
    final env = ref.watch(appConfigProvider).env;
    final mode = ThemeMode.values.firstWhere((m) => m.name == env.themeMode, orElse: () => ThemeMode.system);
    return ThemeChoice(env.themePalette, mode);
  }

  bool get canChange => ref.read(appConfigProvider).env.devTools;

  void setPalette(String palette) {
    if (canChange && ref.read(appConfigProvider).theme.paletteNames.contains(palette)) {
      state = ThemeChoice(palette, state.mode);
    }
  }

  void setMode(ThemeMode mode) {
    if (canChange) state = ThemeChoice(state.palette, mode);
  }
}

final themeChoiceProvider = NotifierProvider<ThemeChoiceController, ThemeChoice>(ThemeChoiceController.new);
