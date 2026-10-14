// Shared test setup: a real AppConfig from the YAML files, the whole app with mock data and no delays,
// and navigation by path.
import 'package:craftstream/app.dart';
import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/env.dart';
import 'package:craftstream/core/router.dart';
import 'package:craftstream/data/mock/mock_store.dart';
import 'package:craftstream/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> testEnvValues({String mode = 'light', bool devTools = true, bool mockData = true}) =>
    {
      'APP_ENV': 'dev',
      'API_HOST': 'http://localhost:8000',
      'THEME_MODE': mode,
      'DEV_TOOLS': devTools,
      'MOCK_DATA': mockData,
      'LOG_LEVEL': 'debug',
    };

Future<AppConfig> testConfig({String mode = 'light', bool devTools = true, bool mockData = true}) =>
    loadAppConfig(
        env: AppEnv.parse(testEnvValues(mode: mode, devTools: devTools, mockData: mockData)));

/// Pumps the whole app at [size] and opens [location]. Returns the provider container.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  AppConfig config, {
  Size size = const Size(390, 844),
  String location = '/discover',
  Duration chunkDelay = Duration.zero,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      appConfigProvider.overrideWithValue(config),
      mockStoreProvider.overrideWithValue(
        MockStore(latency: Duration.zero, chunkDelay: chunkDelay, processingTime: Duration.zero),
      ),
      ...overrides,
    ],
    child: const CraftStreamApp(),
  ));
  final container = ProviderScope.containerOf(tester.element(find.byType(CraftStreamApp)));
  container.read(routerProvider).go(location);
  await settle(tester);
  return container;
}

/// Lets zero-delay mock futures and route changes finish. (pumpAndSettle would wait forever on skeleton
/// and progress animations.)
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A string from strings.yml, so tests don't repeat copy.
String str(AppConfig config, String key, [Map<String, Object> args = const {}]) => config.strings.get(key, args);
