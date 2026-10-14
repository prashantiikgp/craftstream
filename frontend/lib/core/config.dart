/// Everything loaded and validated at startup: the environment and the rule engines.
/// If any part fails, main.dart shows ConfigErrorApp instead of running with half the config.
library;

import 'package:flutter/material.dart' show Brightness, ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/catalog/filters_engine.dart';
import '../domain/catalog/filters_loader.dart';
import '../domain/media/player_engine.dart';
import '../domain/media/player_loader.dart';
import '../domain/media/upload_engine.dart';
import '../domain/media/upload_loader.dart';
import '../domain/ui/layout_engine.dart';
import '../domain/ui/layout_loader.dart';
import '../domain/ui/strings_engine.dart';
import '../domain/ui/strings_loader.dart';
import '../domain/ui/theme_engine.dart';
import '../domain/ui/theme_loader.dart';
import 'env.dart';

class AppConfig {
  final AppEnv env;
  final ThemeEngine theme;
  final LayoutEngine layout;
  final StringsEngine strings;
  final FiltersEngine filters;
  final PlayerEngine player;
  final UploadEngine upload;
  const AppConfig({
    required this.env,
    required this.theme,
    required this.layout,
    required this.strings,
    required this.filters,
    required this.player,
    required this.upload,
  });
}

Future<AppConfig> loadAppConfig({AppEnv? env, AssetBundle? bundle}) async {
  final e = env ?? AppEnv.fromCompiledValues();
  final theme = ThemeEngine(await loadThemeRules(bundle: bundle));
  return AppConfig(
    env: e,
    theme: theme,
    layout: LayoutEngine(await loadLayoutRules(bundle: bundle)),
    strings: StringsEngine(await loadStringsRules(bundle: bundle)),
    filters: FiltersEngine(await loadFiltersRules(bundle: bundle)),
    player: PlayerEngine(await loadPlayerRules(bundle: bundle)),
    upload: UploadEngine(await loadUploadRules(bundle: bundle)),
  );
}

/// Overridden in main.dart with the loaded config.
final appConfigProvider = Provider<AppConfig>((ref) => throw StateError('appConfigProvider not initialised'));

/// Light or dark. Starts from the environment (`system` follows the device); the theme toggle switches it.
class ThemeChoiceController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final env = ref.watch(appConfigProvider).env;
    return ThemeMode.values.firstWhere((m) => m.name == env.themeMode, orElse: () => ThemeMode.system);
  }

  void setMode(ThemeMode mode) => state = mode;

  /// Flip to the other mode; [platform] is what `system` currently shows.
  void toggle(Brightness platform) {
    final dark = state == ThemeMode.dark || (state == ThemeMode.system && platform == Brightness.dark);
    state = dark ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeChoiceProvider = NotifierProvider<ThemeChoiceController, ThemeMode>(ThemeChoiceController.new);
