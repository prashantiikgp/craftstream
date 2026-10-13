// Every brand widget paints in every palette and mode, and poster looks are stable per tag.
import 'package:craftstream/domain/ui/theme_engine.dart';
import 'package:craftstream/domain/ui/theme_loader.dart';
import 'package:craftstream/shared/brand/brand.dart';
import 'package:craftstream/shared/brand/brand_painters.dart' show MarkPainter;
import 'package:craftstream/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ThemeEngine engine;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    engine = ThemeEngine(await loadThemeRules());
  });

  for (final palette in ['saffron', 'terracotta', 'marigold']) {
    for (final brightness in Brightness.values) {
      testWidgets('brand widgets: $palette ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(1280, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: buildTheme(engine.resolve(palette, brightness)),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Wrap(spacing: 16, runSpacing: 16, children: [
                const BrandLockup(height: 40),
                const BrandLockup(height: 24, showWordmark: false),
                for (final size in [16.0, 24.0, 48.0, 96.0]) BrandMark(size: size),
                for (final tone in MarkTone.values) BrandMark(tone: tone),
                for (final kind in SpotKind.values) SpotIllustration(kind, width: 200),
                for (final tag in ['pottery', 'textiles', 'woodwork', 'brass', 'jewellery', 'embroidery', 'kites', null])
                  SizedBox(width: 240, child: ProductPosterPlaceholder(tag: tag)),
              ]),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(find.text('CraftStream', findRichText: true), findsOneWidget);
        expect(find.bySemanticsLabel('CraftStream'), findsWidgets);
      });
    }
  }

  test('known crafts get their own texture; unknown tags get a stable one', () {
    expect(ProductPosterPlaceholder.motifFor('pottery'), PosterMotif.rings);
    expect(ProductPosterPlaceholder.motifFor('Textiles '), PosterMotif.weave);
    expect(ProductPosterPlaceholder.motifFor('woodwork'), PosterMotif.grain);
    expect(ProductPosterPlaceholder.motifFor('brass'), PosterMotif.hammered);
    expect(ProductPosterPlaceholder.motifFor('jewellery'), PosterMotif.beads);
    expect(ProductPosterPlaceholder.motifFor('kites'), ProductPosterPlaceholder.motifFor('kites'));
    expect(ProductPosterPlaceholder.motifFor(null), isA<PosterMotif>());
  });

  test('the mark is drawn from one geometry for every size', () {
    // Below 24 px the wheel is dropped (it would be under a pixel thick).
    expect(MarkPainter.wheelFits(16), isFalse);
    expect(MarkPainter.wheelFits(48), isTrue);
  });
}
