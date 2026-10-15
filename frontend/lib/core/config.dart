/// Everything loaded and validated at startup: the environment and the rule engines.
/// If any part fails, main.dart shows ConfigErrorApp instead of running with half the config.
library;

import 'package:flutter/material.dart' show Brightness, ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/generated/models.dart' show ProductSummary;
import '../domain/app/env_rules_engine.dart';
import '../domain/app/env_rules_loader.dart';
import '../domain/app/navigation_engine.dart';
import '../domain/app/navigation_loader.dart';
import '../domain/app/routes_engine.dart';
import '../domain/app/routes_loader.dart';
import '../domain/catalog/filters_engine.dart';
import '../domain/catalog/filters_loader.dart';
import '../domain/logs/activity_log_engine.dart';
import '../domain/logs/activity_log_loader.dart';
import '../domain/dev/mock_engine.dart';
import '../domain/dev/mock_loader.dart';
import '../domain/media/player_engine.dart';
import '../domain/media/player_loader.dart';
import '../domain/media/upload_engine.dart';
import '../domain/orders/orders_engine.dart';
import '../domain/orders/orders_loader.dart';
import '../domain/media/upload_loader.dart';
import '../domain/ui/art_engine.dart';
import '../domain/ui/art_loader.dart';
import '../domain/ui/bricks_engine.dart';
import '../domain/ui/bricks_loader.dart';
import '../domain/ui/format_engine.dart';
import '../domain/ui/format_loader.dart';
import '../domain/ui/icons_engine.dart';
import '../domain/ui/icons_loader.dart';
import '../domain/ui/layout_engine.dart';
import '../domain/ui/layout_loader.dart';
import '../domain/ui/screen_engine.dart';
import '../domain/ui/screen_loader.dart';
import '../domain/ui/status_engine.dart';
import '../domain/ui/status_loader.dart';
import '../domain/ui/strings_engine.dart';
import '../domain/ui/strings_loader.dart';
import '../domain/ui/theme_engine.dart';
import '../domain/ui/theme_loader.dart';
import 'env.dart';

class AppConfig {
  final AppEnv env;

  /// app/env_rules.yml: the environment policy and the Android dev host.
  final EnvRulesEngine envRules;
  final ThemeEngine theme;
  final LayoutEngine layout;
  final StringsEngine strings;
  final FiltersEngine filters;
  final PlayerEngine player;
  final UploadEngine upload;
  final RoutesEngine routes;
  final NavigationEngine navigation;
  final IconsEngine icons;
  final StatusEngine status;
  final ArtEngine art;
  final BricksEngine bricks;
  final ScreenEngine screens;
  final OrdersEngine orders;
  final ActivityLogEngine activityLog;

  /// ui/format.yml: money, file sizes, video lengths, dates and times.
  final FormatEngine format;

  /// dev/mock.yml: the fake backend used when MOCK_DATA=true.
  final MockEngine mock;
  const AppConfig({
    required this.env,
    required this.envRules,
    required this.theme,
    required this.layout,
    required this.strings,
    required this.filters,
    required this.player,
    required this.upload,
    required this.routes,
    required this.navigation,
    required this.icons,
    required this.status,
    required this.art,
    required this.bricks,
    required this.screens,
    required this.orders,
    required this.activityLog,
    required this.format,
    required this.mock,
  });
}

/// A rule file names something another rule file defines, and it is not there.
class ConfigCrossCheckError implements Exception {
  final List<String> problems;
  const ConfigCrossCheckError(this.problems);
  @override
  String toString() => 'Rule files disagree:\n- ${problems.join('\n- ')}';
}

Future<AppConfig> loadAppConfig({AppEnv? env, AssetBundle? bundle}) async {
  final envRules = EnvRulesEngine(await loadEnvRules(bundle: bundle));
  // A given env (tests) passes the same policy as the compiled-in one.
  final e = env == null ? AppEnv.fromCompiledValues(envRules) : env.checkedBy(envRules);
  final theme = ThemeEngine(await loadThemeRules(bundle: bundle));
  final strings = StringsEngine(await loadStringsRules(bundle: bundle));
  final routes = RoutesEngine(await loadRoutesRules(bundle: bundle));
  final navigation = NavigationEngine(await loadNavigationRules(bundle: bundle));
  final icons = IconsEngine(await loadIconsRules(bundle: bundle));
  final status = StatusEngine(await loadStatusRules(bundle: bundle));
  final art = ArtEngine(await loadArtRules(bundle: bundle));
  final bricks = BricksEngine(await loadBricksRules(bundle: bundle));
  final filters = FiltersEngine(await loadFiltersRules(bundle: bundle));
  final mock = MockEngine(await loadMockRules(bundle: bundle));
  _crossCheck(
    theme: theme,
    strings: strings,
    routes: routes,
    navigation: navigation,
    status: status,
    art: art,
    filters: filters,
    mock: mock,
  );
  final layout = LayoutEngine(await loadLayoutRules(bundle: bundle));
  final refs = brickRefs(
    theme: theme,
    strings: strings,
    routes: routes,
    navigation: navigation,
    icons: icons,
    art: art,
    layout: layout,
  );
  final screens = ScreenEngine(
    await loadScreenRules(bundle: bundle),
    bricks,
    refs,
    backdrops: art.backdropNames.toSet(),
  );
  final unrouted = routes.screenNames.difference(screens.names.toSet());
  if (unrouted.isNotEmpty) {
    throw ConfigCrossCheckError(['routes.yml shows screens with no YAML: ${unrouted.join(', ')}']);
  }
  return AppConfig(
    env: e,
    envRules: envRules,
    theme: theme,
    layout: layout,
    strings: strings,
    filters: filters,
    player: PlayerEngine(await loadPlayerRules(bundle: bundle)),
    upload: UploadEngine(await loadUploadRules(bundle: bundle)),
    routes: routes,
    navigation: navigation,
    icons: icons,
    status: status,
    art: art,
    bricks: bricks,
    screens: screens,
    orders: OrdersEngine(await loadOrdersRules(bundle: bundle)),
    activityLog: ActivityLogEngine(await loadActivityLogRules(bundle: bundle)),
    format: FormatEngine(await loadFormatRules(bundle: bundle)),
    mock: mock,
  );
}

/// Everything a screen's bricks may name, from the other rule files.
BrickRefs brickRefs({
  required ThemeEngine theme,
  required StringsEngine strings,
  required RoutesEngine routes,
  required NavigationEngine navigation,
  required IconsEngine icons,
  required ArtEngine art,
  required LayoutEngine layout,
}) {
  final t = theme.light;
  return BrickRefs(
    hasText: strings.has,
    acceptsRoute: routes.acceptsTemplate,
    icons: icons.names.toSet(),
    roles: navigation.names.toSet(),
    tones: t.toneNames.toSet(),
    colors: {
      ...t.namedColors.keys,
      for (final tone in t.toneNames)
        for (final part in t.tone(tone).parts.keys) '$tone.$part',
    },
    styles: t.styles.keys.toSet(),
    spaces: spacingSteps,
    doorArts: art.doorNames.toSet(),
    sizeClasses: layout.sizeClassNames.toSet(),
  );
}

/// Spacing step names in theme.yml `spacing`.
const spacingSteps = {'xxs', 'xs', 'sm', 'md', 'lg', 'xl', 'xxl', 'xxxl', 'section'};

void _crossCheck({
  required ThemeEngine theme,
  required StringsEngine strings,
  required RoutesEngine routes,
  required NavigationEngine navigation,
  required StatusEngine status,
  required ArtEngine art,
  required FiltersEngine filters,
  required MockEngine mock,
}) {
  final accents = theme.light.accents.keys.toSet(), tones = theme.light.toneNames.toSet();
  final problems = <String>[
    for (final r in navigation.names) ...[
      if (!accents.contains(navigation.role(r).accent))
        'navigation.yml $r.accent: "${navigation.role(r).accent}" is not in theme.yml accents',
      if (!strings.has(navigation.role(r).label))
        'navigation.yml $r.label: "${navigation.role(r).label}" is not in strings.yml',
      if (routes.match(navigation.role(r).home) == null)
        'navigation.yml $r.home: "${navigation.role(r).home}" is not a route',
    ],
    for (final a in art.accents)
      if (!accents.contains(a)) 'art.yml: accent "$a" is not in theme.yml accents',
    for (final tone in status.tones)
      if (!tones.contains(tone)) 'status.yml: tone "$tone" is not in theme.yml tones',
    for (final key in status.stringKeys)
      if (!strings.has(key)) 'status.yml: "$key" is not in strings.yml',
    for (final key in filters.sortLabels)
      if (!strings.has(key)) 'filters.yml sort label: "$key" is not in strings.yml',
    for (final field in filters.sortFields.difference(_productSummaryFields))
      'filters.yml sort field: "$field" is not a ProductSummary field (models/product_summary.yml)',
    for (final s in mock.statuses.difference(status.values('video').toSet()))
      'mock.yml: product status "$s" is not a video status in status.yml',
  ];
  if (problems.isNotEmpty) throw ConfigCrossCheckError(problems);
}

/// The fields a search result has, as the API names them (what a sort may read).
final _productSummaryFields = const ProductSummary(
  id: '',
  title: '',
  price: 0,
  currency: '',
  tags: [],
  artisanName: '',
).toJson().keys.toSet();

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
