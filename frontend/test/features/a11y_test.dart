// Icon buttons are at least theme.yml focus.min_target, cards read their strings.yml a11y template to screen
// readers, and reduced motion turns off the hover lift and press scale.
import 'package:craftstream/core/config.dart';
import 'package:craftstream/core/router.dart';
import 'package:craftstream/shared/bricks/kit.dart';
import 'package:craftstream/shared/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

void main() {
  late AppConfig config;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    config = await testConfig();
  });

  const phone = Size(360, 640);

  Future<void> go(WidgetTester tester, ProviderContainer container, String location) async {
    container.read(routerProvider).go(location);
    await settle(tester);
  }

  testWidgets('icon buttons are at least focus.min_target: back, home, theme toggle, refresh', (tester) async {
    final handle = tester.ensureSemantics();
    final min = config.theme.light.minTarget;
    final container = await pumpApp(tester, config, size: phone, location: '/product/p_01');
    void checkSize(String key) {
      final size = tester.getSize(find.bySemanticsLabel(str(config, key)).first);
      expect(size.width, greaterThanOrEqualTo(min), reason: '$key is ${size.width} wide');
      expect(size.height, greaterThanOrEqualTo(min), reason: '$key is ${size.height} high');
    }

    checkSize('common.back');
    checkSize('theme.to_dark');
    await go(tester, container, '/logs');
    checkSize('logs.refresh');
    checkSize('common.home');
    handle.dispose();
  });

  testWidgets('a product card reads its strings.yml a11y template', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, config, size: phone, location: '/discover');
    final label = str(config, 'a11y.product_card', {
      'title': 'Hand-thrown clay mug',
      'artisan': 'Meera Devi',
      'price': config.format.money(450, 'INR'),
    });
    // The node also carries the card's own texts after the label.
    expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}')), findsOneWidget);
    handle.dispose();
  });

  group('reduced motion', () {
    Future<Matrix4> transformWhilePressed(WidgetTester tester, {required bool reduced}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(config.theme.light),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Center(
              child: Pressable(
                accent: config.theme.light.tone('brand').fill,
                onTap: () {},
                builder: (_, _) => const SizedBox(width: 120, height: 80),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.byType(Pressable)));
      await tester.pump();
      final press = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump(const Duration(seconds: 1));
      final box = tester.widget<AnimatedContainer>(
        find.descendant(of: find.byType(Pressable), matching: find.byType(AnimatedContainer)),
      );
      await press.up();
      await mouse.removePointer();
      return box.transform ?? Matrix4.identity();
    }

    testWidgets('normally a hovered, pressed card rises and sinks', (tester) async {
      expect(await transformWhilePressed(tester, reduced: false), isNot(Matrix4.identity()));
    });

    testWidgets('with reduced motion it stays put', (tester) async {
      expect(await transformWhilePressed(tester, reduced: true), Matrix4.identity());
    });
  });
}
