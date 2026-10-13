// Interactive states use the brand ramp, not Material's secondary defaults (which show the palette's secondary colour).
import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/env.dart';
import 'package:craftstream/shared/widgets/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppConfig config;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final env = AppEnv.parse({
      'APP_ENV': 'dev', 'API_HOST': 'http://localhost:8000', 'THEME_PALETTE': 'saffron',
      'THEME_MODE': 'light', 'DEV_TOOLS': true, 'MOCK_DATA': true, 'LOG_LEVEL': 'debug',
    });
    config = await loadAppConfig(env: env);
  });

  Iterable<Color?> materialColors(WidgetTester tester, Finder within) => tester
      .widgetList<Material>(find.descendant(of: within, matching: find.byType(Material)))
      .map((m) => m.color);

  for (final palette in ['saffron', 'terracotta', 'marigold']) {
    for (final brightness in Brightness.values) {
      testWidgets('brand states: $palette ${brightness.name}', (tester) async {
        final t = config.theme.resolve(palette, brightness);
        await tester.pumpWidget(MaterialApp(
          theme: buildTheme(t),
          home: Scaffold(
            body: Column(children: [
              SegmentedButton<int>(
                segments: const [ButtonSegment(value: 1, label: Text('On')), ButtonSegment(value: 2, label: Text('Off'))],
                selected: const {1},
                onSelectionChanged: (_) {},
              ),
              AppButton('Saving', onPressed: () {}, loading: true),
            ]),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 300));

        final segment = find.ancestor(of: find.text('On'), matching: find.byType(TextButton)).first;
        expect(materialColors(tester, segment), contains(t.brandLl));
        expect(materialColors(tester, segment), isNot(contains(t.secondaryL)));

        final loading = find.byType(AppButton);
        expect(materialColors(tester, loading), contains(t.brand), reason: 'a loading button keeps its brand fill');
      });
    }
  }
}
