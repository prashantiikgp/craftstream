// Loading placeholders pulse at theme.yml's motion.skeleton_* pace, and hold still under reduced motion.
import 'package:craftstream/core/config.dart';
import 'package:craftstream/shared/bricks/browse_bricks.dart';
import 'package:craftstream/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

void main() {
  late AppConfig config;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    config = await testConfig();
  });

  Future<double?> opacityAfter(WidgetTester tester, Duration elapsed, {bool reduced = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(config.theme.light),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const SkeletonPulse(child: SizedBox(width: 10, height: 10)),
        ),
      ),
    );
    await tester.pump(elapsed);
    final fade = find
        .byType(FadeTransition)
        .evaluate()
        .where((e) => e.findAncestorWidgetOfExactType<SkeletonPulse>() != null);
    return fade.isEmpty ? null : (fade.first.widget as FadeTransition).opacity.value;
  }

  testWidgets('pulses between skeleton_min_opacity and full over skeleton_pulse_ms', (tester) async {
    final t = config.theme.light;
    expect(t.skeletonPulse, const Duration(milliseconds: 1100));
    expect(await opacityAfter(tester, Duration.zero), closeTo(t.skeletonMinOpacity, 0.001));
    expect(await opacityAfter(tester, t.skeletonPulse), closeTo(1.0, 0.001));
  });

  testWidgets('holds still under reduced motion', (tester) async {
    expect(await opacityAfter(tester, const Duration(milliseconds: 500), reduced: true), isNull);
  });
}
