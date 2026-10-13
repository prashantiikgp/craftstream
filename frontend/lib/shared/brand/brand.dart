/// Brand artwork as widgets. Everything is drawn in code from the active palette (no image downloads, no SVG
/// package), so it follows palette + light/dark and costs nothing on a 50 kbps link.
///
///   BrandLockup(height: 28)                       // mark + "CraftStream" for app bars
///   BrandMark(size: 48)                           // the mark alone
///   SpotIllustration(SpotKind.emptySearch)        // empty / processing / order placed / slow network
///   ProductPosterPlaceholder(tag: 'pottery')      // 16:9 poster until a real thumbnail exists
library;

import 'package:flutter/material.dart';

import '../../domain/ui/theme_engine.dart';
import '../theme/app_theme.dart';
import 'brand_painters.dart';

export 'brand_painters.dart' show SpotKind, PosterMotif;

enum MarkTone { brand, ink, onBrand }

/// The vessel-and-play mark. [tone] picks the colour from the palette; the triangle is see-through.
class BrandMark extends StatelessWidget {
  final double size;
  final MarkTone tone;
  final String? semanticLabel;
  const BrandMark({super.key, this.size = 32, this.tone = MarkTone.brand, this.semanticLabel = 'CraftStream'});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch (tone) { MarkTone.brand => t.brand, MarkTone.ink => t.ink, MarkTone.onBrand => t.onBrand };
    final mark = CustomPaint(size: Size.square(size), painter: MarkPainter(color: color));
    return semanticLabel == null ? ExcludeSemantics(child: mark) : Semantics(label: semanticLabel, image: true, child: mark);
  }
}

/// Mark + wordmark. "Craft" in ink, "Stream" in brand ink (orange text that passes contrast).
class BrandLockup extends StatelessWidget {
  final double height;
  final bool showWordmark;
  const BrandLockup({super.key, this.height = 32, this.showWordmark = true});

  static const wordmarkFamily = 'Poppins';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = TextStyle(
      fontFamily: wordmarkFamily,
      fontWeight: FontWeight.w700,
      fontSize: height * 0.62,
      height: 1,
      letterSpacing: -height * 0.012,
      color: t.ink,
    );
    return Semantics(
      label: 'CraftStream',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        BrandMark(size: height, semanticLabel: null),
        if (showWordmark) ...[
          SizedBox(width: height * 0.28),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Craft'),
              TextSpan(text: 'Stream', style: TextStyle(color: t.brandInk)),
            ]),
            style: style,
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ]),
    );
  }
}

/// Small illustrations for empty, processing, success and slow-network states. Decorative: screens put the
/// message in text next to them, so they are hidden from screen readers.
class SpotIllustration extends StatelessWidget {
  final SpotKind kind;
  final double width;
  const SpotIllustration(this.kind, {super.key, this.width = 160});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: Size(width, width * 0.75),
          painter: SpotPainter(kind, BrandPalette.of(context.tokens)),
        ),
      );
}

/// A 16:9 poster for a product without a thumbnail: tinted and textured by craft, with the mark as the play
/// affordance. The same tag always gets the same look.
class ProductPosterPlaceholder extends StatelessWidget {
  final String? tag;
  final bool showMark;
  final BorderRadius? borderRadius;
  const ProductPosterPlaceholder({super.key, this.tag, this.showMark = true, this.borderRadius});

  static const _motifByTag = <String, PosterMotif>{
    'pottery': PosterMotif.rings, 'ceramics': PosterMotif.rings, 'clay': PosterMotif.rings,
    'terracotta': PosterMotif.rings,
    'textiles': PosterMotif.weave, 'weaving': PosterMotif.weave, 'handloom': PosterMotif.weave,
    'embroidery': PosterMotif.stitch, 'block-print': PosterMotif.stitch,
    'woodwork': PosterMotif.grain, 'wood': PosterMotif.grain, 'carving': PosterMotif.grain,
    'bamboo': PosterMotif.grain, 'cane': PosterMotif.weave,
    'brass': PosterMotif.hammered, 'metal': PosterMotif.hammered, 'copper': PosterMotif.hammered,
    'dhokra': PosterMotif.hammered,
    'jewellery': PosterMotif.beads, 'jewelry': PosterMotif.beads, 'beads': PosterMotif.beads,
    'kundan': PosterMotif.beads,
    'kantha': PosterMotif.stitch, 'ikat': PosterMotif.weave, 'toys': PosterMotif.grain,
    'metalwork': PosterMotif.hammered, 'bidri': PosterMotif.hammered,
  };

  /// Which texture a tag gets. Unknown tags get a stable pick from all motifs.
  static PosterMotif motifFor(String? tag) {
    final key = (tag ?? '').trim().toLowerCase();
    final known = _motifByTag[key];
    if (known != null) return known;
    var h = 0;
    for (final u in key.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return PosterMotif.values[h % PosterMotif.values.length];
  }

  /// Background wash and texture/mark colour for a motif, from the palette.
  static (Color wash, Color accent) colorsFor(PosterMotif motif, DesignTokens t) => switch (motif) {
        PosterMotif.rings || PosterMotif.grain => (t.brandL, t.brand),
        PosterMotif.weave => (t.secondaryL, t.secondary),
        PosterMotif.hammered => (t.warning.wash, t.warning.fill),
        PosterMotif.beads => (t.info.wash, t.info.fill),
        PosterMotif.stitch => (t.success.wash, t.success.fill),
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final motif = motifFor(tag);
    final (wash, accent) = colorsFor(motif, t);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: CustomPaint(
            painter: PosterPainter(motif: motif, wash: wash, accent: accent, disc: t.card, showMark: showMark),
          ),
        ),
      ),
    );
  }
}
