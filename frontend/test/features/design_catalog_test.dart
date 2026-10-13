// The whole catalog renders in every palette and mode without layout errors, from the real YAML files.
import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/env.dart';
import 'package:craftstream/features/design_catalog/design_catalog_screen.dart';
import 'package:craftstream/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppConfig config;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final env = AppEnv.parse({
      'APP_ENV': 'dev', 'API_HOST': 'http://localhost:8000', 'THEME_PALETTE': 'saffron',
      'THEME_MODE': 'light', 'DEV_TOOLS': true, 'LOG_LEVEL': 'debug',
    });
    config = await loadAppConfig(env: env);
  });

  for (final palette in ['saffron', 'terracotta', 'marigold']) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(390, 844), const Size(1280, 900)]) {
        testWidgets('catalog: $palette ${brightness.name} ${size.width.toInt()}px', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(ProviderScope(
            overrides: [appConfigProvider.overrideWithValue(config)],
            child: MaterialApp(
              theme: buildTheme(config.theme.resolve(palette, brightness)),
              home: const DesignCatalogScreen(),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
          expect(find.textContaining('readability checks pass'), findsOneWidget);
        });
      }
    }
  }

  test('an env palette that is not in theme.yml stops startup', () async {
    final env = AppEnv.parse({
      'APP_ENV': 'dev', 'API_HOST': 'http://localhost:8000', 'THEME_PALETTE': 'neon',
      'THEME_MODE': 'light', 'DEV_TOOLS': true, 'LOG_LEVEL': 'debug',
    });
    expect(() => loadAppConfig(env: env), throwsA(isA<EnvError>()));
  });
}
