/// Painters for the brand artwork. They take colours as parameters (a [BrandPalette]) and never read the theme,
/// so the same code paints the in-app widgets and the generated icon files.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../domain/ui/theme_engine.dart';
import 'brand_geometry.dart';

/// The colours the artwork uses, picked from the active palette.
class BrandPalette {
  final Color brand, brandD, brandL, brandLl, onBrand;
  final Color secondary, secondaryL;
  final Color card, ink, sub, hair;
  final Color success, successWash, warning, warningWash, info, infoWash;

  const BrandPalette({
    required this.brand,
    required this.brandD,
    required this.brandL,
    required this.brandLl,
    required this.onBrand,
    required this.secondary,
    required this.secondaryL,
    required this.card,
    required this.ink,
    required this.sub,
    required this.hair,
    required this.success,
    required this.successWash,
    required this.warning,
    required this.warningWash,
    required this.info,
    required this.infoWash,
  });

  factory BrandPalette.of(DesignTokens t) => BrandPalette(
        brand: t.brand,
        brandD: t.brandD,
        brandL: t.brandL,
        brandLl: t.brandLl,
        onBrand: t.onBrand,
        secondary: t.secondary,
        secondaryL: t.secondaryL,
        card: t.card,
        ink: t.ink,
        sub: t.sub,
        hair: t.hair,
        success: t.success.fill,
        successWash: t.success.wash,
        warning: t.warning.fill,
        warningWash: t.warning.wash,
        info: t.info.fill,
        infoWash: t.info.wash,
      );
}

// ---------------------------------------------------------------------------------------------------------------
// Mark

/// The vessel-and-play mark in one colour; the triangle is a hole, so whatever is behind shows through.
/// Below 24 px the wheel is dropped: it would be thinner than a pixel.
class MarkPainter extends CustomPainter {
  final Color color;
  final bool wheel;
  const MarkPainter({required this.color, this.wheel = true});

  static bool wheelFits(double size) => size >= 24;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final rect = Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side);
    canvas.drawPath(toPath(markCmds(wheel: wheel && wheelFits(side)), rect), Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(MarkPainter old) => old.color != color || old.wheel != wheel;
}

/// App icon: the mark in [fg] on a [bg] rounded square ([cornerFraction] of the side; 0 = full bleed square).
/// [markFraction] is how much of the side the mark takes (maskable icons keep it inside the 80 % safe zone).
void paintAppIcon(Canvas canvas, Size size,
    {required Color bg, required Color fg, double cornerFraction = 0.225, double inset = 0, double markFraction = 0.62}) {
  final s = size.shortestSide;
  final square = Rect.fromLTWH(inset, inset, s - inset * 2, s - inset * 2);
  final paint = Paint()..isAntiAlias = true;
  canvas.drawRRect(RRect.fromRectAndRadius(square, Radius.circular(square.width * cornerFraction)), paint..color = bg);
  final m = square.width * markFraction;
  // Nudge down a touch: the vessel's visual mass sits above its box centre.
  final markRect = Rect.fromCenter(center: square.center.translate(0, square.width * 0.01), width: m, height: m);
  canvas.drawPath(toPath(markCmds(wheel: MarkPainter.wheelFits(m)), markRect), paint..color = fg);
}

// ---------------------------------------------------------------------------------------------------------------
// Spot illustrations (160 × 120 design box)

enum SpotKind { emptySearch, processing, orderPlaced, slowNetwork }

class SpotPainter extends CustomPainter {
  final SpotKind kind;
  final BrandPalette c;
  const SpotPainter(this.kind, this.c);

  static const designSize = Size(160, 120);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / designSize.width, size.height / designSize.height);
    canvas.save();
    canvas.translate((size.width - designSize.width * scale) / 2, (size.height - designSize.height * scale) / 2);
    canvas.scale(scale);
    switch (kind) {
      case SpotKind.emptySearch:
        _emptySearch(canvas);
      case SpotKind.processing:
        _processing(canvas);
      case SpotKind.orderPlaced:
        _orderPlaced(canvas);
      case SpotKind.slowNetwork:
        _slowNetwork(canvas);
    }
    canvas.restore();
  }

  Paint _fill(Color color) => Paint()..color = color..isAntiAlias = true;
  Paint _stroke(Color color, double w) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  /// A soft, slightly lopsided clay-like blob behind every subject.
  void _blob(Canvas canvas, Color color) {
    final p = Path()
      ..moveTo(80, 10)
      ..cubicTo(118, 8, 146, 30, 144, 62)
      ..cubicTo(142, 96, 112, 114, 78, 112)
      ..cubicTo(42, 110, 14, 92, 16, 60)
      ..cubicTo(18, 30, 46, 12, 80, 10)
      ..close();
    canvas.drawPath(p, _fill(color));
  }

  void _sparkle(Canvas canvas, Offset at, double r, Color color) {
    final p = Path()
      ..moveTo(at.dx, at.dy - r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)
      ..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)
      ..close();
    canvas.drawPath(p, _fill(color));
  }

  /// An empty clay bowl and a magnifying glass: "nothing matches".
  void _emptySearch(Canvas canvas) {
    _blob(canvas, c.brandLl);
    // bowl body
    final bowl = Path()
      ..moveTo(34, 70)
      ..cubicTo(36, 92, 52, 100, 68, 100)
      ..cubicTo(84, 100, 100, 92, 102, 70)
      ..close();
    canvas.drawPath(bowl, _fill(c.brand));
    canvas.drawOval(const Rect.fromLTRB(34, 63, 102, 77), _fill(c.brandD)); // the empty inside
    canvas.drawOval(const Rect.fromLTRB(40, 66, 96, 75), _fill(c.brandL.withValues(alpha: 0.35)));
    canvas.drawRRect(RRect.fromLTRBR(56, 100, 80, 104, const Radius.circular(2)), _fill(c.brandD)); // foot
    // magnifier
    canvas.drawLine(const Offset(119, 58), const Offset(133, 72), _stroke(c.secondary, 8));
    canvas.drawCircle(const Offset(106, 45), 17, _fill(c.card));
    canvas.drawCircle(const Offset(106, 45), 17, _stroke(c.secondary, 6));
    canvas.drawArc(Rect.fromCircle(center: const Offset(106, 45), radius: 10), deg(200), deg(70), false,
        _stroke(c.secondaryL, 3));
    _sparkle(canvas, const Offset(36, 36), 6, c.brand);
    _sparkle(canvas, const Offset(52, 22), 3.5, c.secondary);
  }

  /// A progress ring, an upward arrow and chunks being sent: "uploading / processing".
  void _processing(Canvas canvas) {
    _blob(canvas, c.secondaryL);
    const centre = Offset(80, 54);
    canvas.drawCircle(centre, 32, _fill(c.card));
    canvas.drawCircle(centre, 32, _stroke(c.brandL, 8));
    canvas.drawArc(Rect.fromCircle(center: centre, radius: 32), deg(-90), deg(250), false, _stroke(c.brand, 8));
    // arrow
    canvas.drawLine(const Offset(80, 70), const Offset(80, 40), _stroke(c.secondary, 7));
    final head = Path()
      ..moveTo(68, 50)
      ..lineTo(80, 38)
      ..lineTo(92, 50);
    canvas.drawPath(head, _stroke(c.secondary, 7));
    // resumable chunks: three sent, two waiting
    for (var i = 0; i < 5; i++) {
      final r = RRect.fromLTRBR(53.0 + i * 11, 98, 62.0 + i * 11, 104, const Radius.circular(2));
      canvas.drawRRect(r, _fill(i < 3 ? c.brand : c.hair));
    }
    _sparkle(canvas, const Offset(124, 26), 5, c.brand);
  }

  /// A kraft-wrapped parcel tied with thread and a check badge: "order placed".
  void _orderPlaced(Canvas canvas) {
    _blob(canvas, c.brandLl);
    canvas.drawRRect(RRect.fromLTRBR(48, 54, 108, 100, const Radius.circular(5)), _fill(c.brand));
    canvas.drawRRect(RRect.fromLTRBR(44, 44, 112, 58, const Radius.circular(4)), _fill(c.brandD));
    // thread
    canvas.drawRect(const Rect.fromLTRB(75, 44, 81, 100), _fill(c.secondary));
    final bowLeft = Path()
      ..moveTo(78, 44)
      ..cubicTo(68, 26, 54, 34, 62, 42)
      ..cubicTo(66, 46, 74, 46, 78, 44)
      ..close();
    final bowRight = Path()
      ..moveTo(78, 44)
      ..cubicTo(88, 26, 102, 34, 94, 42)
      ..cubicTo(90, 46, 82, 46, 78, 44)
      ..close();
    canvas.drawPath(bowLeft, _fill(c.secondary));
    canvas.drawPath(bowRight, _fill(c.secondary));
    // check badge
    canvas.drawCircle(const Offset(114, 42), 16, _fill(c.success));
    final tick = Path()
      ..moveTo(106.5, 42.5)
      ..lineTo(112, 48)
      ..lineTo(121.5, 37);
    canvas.drawPath(tick, _stroke(c.card, 4.5));
    _sparkle(canvas, const Offset(34, 40), 5, c.secondary);
    _sparkle(canvas, const Offset(132, 74), 3.5, c.brand);
  }

  /// A snail under a weak signal: "slow network, still playing".
  void _slowNetwork(Canvas canvas) {
    _blob(canvas, c.warningWash);
    // signal bars, one lit
    for (var i = 0; i < 4; i++) {
      final h = 8.0 + i * 7;
      canvas.drawRRect(RRect.fromLTRBR(104.0 + i * 9, 50 - h, 110.0 + i * 9, 50, const Radius.circular(2)),
          _fill(i == 0 ? c.brand : c.hair));
    }
    // body
    final body = Path()
      ..moveTo(30, 98)
      ..cubicTo(30, 90, 60, 90, 92, 90)
      ..cubicTo(98, 90, 100, 84, 100, 76)
      ..cubicTo(100, 68, 112, 68, 112, 78)
      ..cubicTo(112, 92, 104, 100, 92, 100)
      ..lineTo(36, 100)
      ..cubicTo(32, 100, 30, 100, 30, 98)
      ..close();
    canvas.drawPath(body, _fill(c.brand));
    // eye stalks
    canvas.drawLine(const Offset(104, 72), const Offset(100, 58), _stroke(c.brand, 3));
    canvas.drawLine(const Offset(108, 72), const Offset(113, 59), _stroke(c.brand, 3));
    canvas.drawCircle(const Offset(100, 57), 3.5, _fill(c.ink));
    canvas.drawCircle(const Offset(113, 58), 3.5, _fill(c.ink));
    // shell with a thrown spiral
    const shell = Offset(64, 72);
    canvas.drawCircle(shell, 22, _fill(c.secondary));
    final spiral = Path()..moveTo(shell.dx, shell.dy);
    for (var a = 0.0; a <= 720; a += 12) {
      final r = 2 + a / 720 * 15;
      spiral.lineTo(shell.dx + r * math.cos(deg(a)), shell.dy + r * math.sin(deg(a)));
    }
    canvas.drawPath(spiral, _stroke(c.secondaryL, 3));
  }

  @override
  bool shouldRepaint(SpotPainter old) => old.kind != kind || old.c != c;
}

// ---------------------------------------------------------------------------------------------------------------
// Poster placeholder

/// A craft-specific surface texture for posters without a real thumbnail.
enum PosterMotif { rings, weave, grain, hammered, beads, stitch }

class PosterPainter extends CustomPainter {
  /// Below this side length (logical px) the texture is skipped: its loops step by a fraction of the
  /// height or width, so a zero or near-zero size would never finish.
  static const minTextureSide = 8.0;

  final PosterMotif motif;
  final Color wash, accent, disc;
  final bool showMark;
  const PosterPainter({
    required this.motif,
    required this.wash,
    required this.accent,
    required this.disc,
    this.showMark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = wash);
    final line = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, h / 90)
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final dot = Paint()..color = accent.withValues(alpha: 0.2)..isAntiAlias = true;
    if (w.isFinite && h.isFinite && math.min(w, h) >= minTextureSide) _paintTexture(canvas, size, line, dot);
    if (showMark && h > 0 && w > 0) {
      final r = h * 0.2;
      final centre = Offset(w / 2, h / 2);
      canvas.drawCircle(centre, r, Paint()..color = disc.withValues(alpha: 0.92)..isAntiAlias = true);
      final m = r * 1.15;
      canvas.drawPath(toPath(markCmds(wheel: false), Rect.fromCenter(center: centre, width: m, height: m)),
          Paint()..color = accent..isAntiAlias = true);
    }
  }

  void _paintTexture(Canvas canvas, Size size, Paint line, Paint dot) {
    final w = size.width, h = size.height;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    switch (motif) {
      case PosterMotif.rings: // throwing rings
        final c = Offset(w * 0.18, h * 1.05);
        for (var r = h * 0.18; r < w * 1.2; r += h * 0.11) {
          canvas.drawCircle(c, r, line);
        }
      case PosterMotif.weave: // basket weave
        final cell = h / 7;
        for (var y = 0.0, row = 0; y < h + cell; y += cell, row++) {
          for (var x = 0.0, col = 0; x < w + cell; x += cell, col++) {
            final across = (row + col).isEven;
            final pad = cell * 0.22;
            for (var k = 0; k < 3; k++) {
              final o = pad + k * (cell - 2 * pad) / 2;
              if (across) {
                canvas.drawLine(Offset(x + pad, y + o), Offset(x + cell - pad, y + o), line);
              } else {
                canvas.drawLine(Offset(x + o, y + pad), Offset(x + o, y + cell - pad), line);
              }
            }
          }
        }
      case PosterMotif.grain: // wood grain
        for (var i = 0; i < 12; i++) {
          final y0 = h * (i + 0.5) / 11;
          final p = Path()..moveTo(-10, y0);
          for (var x = 0.0; x <= w + 10; x += w / 40) {
            p.lineTo(x, y0 + math.sin(x / w * math.pi * 2 + i * 0.7) * h * 0.035 + math.sin(x / w * 9 + i) * h * 0.01);
          }
          canvas.drawPath(p, line);
        }
      case PosterMotif.hammered: // hammered metal
        final step = h / 9;
        for (var y = 0.0, row = 0; y < h + step; y += step * 0.87, row++) {
          for (var x = row.isEven ? 0.0 : step / 2; x < w + step; x += step) {
            canvas.drawCircle(Offset(x, y), step * (0.22 + 0.08 * math.sin(x * 7 + y * 3)), dot);
          }
        }
      case PosterMotif.beads: // strings of beads
        final gap = h / 5;
        for (var s = -h; s < w + h; s += gap * 1.6) {
          for (var t = 0.0; t < h * 1.5; t += gap / 2.2) {
            canvas.drawCircle(Offset(s + t * 0.55, t), h / 40, dot);
          }
        }
      case PosterMotif.stitch: // running stitches
        final gap = h / 6;
        for (var s = -h; s < w + h; s += gap) {
          for (var t = 0.0; t < h * 1.3; t += gap * 0.6) {
            canvas.drawLine(Offset(s + t, t), Offset(s + t + gap * 0.25, t + gap * 0.25), line);
          }
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PosterPainter old) =>
      old.motif != motif || old.wash != wash || old.accent != accent || old.disc != disc || old.showMark != showMark;
}
