/// Artwork from art.yml: named shape sets (backdrops, door art) and a stable poster per product. Pure Dart: the
/// art brick paints what this returns, with colours resolved from the accent names.
library;

import '../../schemas/ui/art_schema.dart';

class ArtRulesError implements Exception {
  final String message;
  const ArtRulesError(this.message);
  @override
  String toString() => 'art.yml: $message';
}

/// A poster: background accent, a circle and a slanted bar, all as fractions of the poster box.
class PosterLook {
  final String background, circleAccent, barAccent;
  final double circleSize, circleX, circleY; // size and x: fraction of width; y: fraction of height
  final double barThickness, barY, barRotate; // thickness: fraction of height; rotate: degrees
  const PosterLook({
    required this.background,
    required this.circleAccent,
    required this.barAccent,
    required this.circleSize,
    required this.circleX,
    required this.circleY,
    required this.barThickness,
    required this.barY,
    required this.barRotate,
  });
}

class ArtEngine {
  final ArtSchema rules;

  /// Validates: every shape has the size its kind needs and a horizontal and vertical position; poster ranges are
  /// [min, max] pairs and there are enough colours for three different parts.
  ArtEngine(this.rules) {
    void checkSet(String where, List<ShapeSchema> shapes) {
      for (final (i, s) in shapes.indexed) {
        final at = '$where[$i]';
        final sized = switch (s.shape) {
          ShapeKind.circle || ShapeKind.square => s.size != null && s.size! > 0,
          ShapeKind.bar => (s.w ?? 0) > 0 && (s.h ?? 0) > 0,
        };
        if (!sized) throw ArtRulesError('$at: a ${s.shape.name} needs ${s.shape == ShapeKind.bar ? 'w and h' : 'size'}');
        if ((s.left == null) == (s.right == null)) throw ArtRulesError('$at needs exactly one of left and right');
        if ((s.top == null) == (s.bottom == null)) throw ArtRulesError('$at needs exactly one of top and bottom');
        if (s.opacity < 0 || s.opacity > 1) throw ArtRulesError('$at: opacity must be 0–1');
      }
    }

    rules.backdrops.forEach((k, v) => checkSet('backdrops.$k', v));
    rules.doors.forEach((k, v) => checkSet('doors.$k', v));
    final p = rules.poster;
    if (p.colors.length < 3) throw const ArtRulesError('poster.colors needs at least 3 accents');
    for (final (name, range) in [
      ('circle.size', p.circle.size),
      ('circle.x', p.circle.x),
      ('circle.y', p.circle.y),
      ('bar.y', p.bar.y),
      ('bar.rotate', p.bar.rotate),
    ]) {
      if (range.length != 2 || range[0] > range[1]) throw ArtRulesError('poster.$name must be [min, max]');
    }
  }

  List<ShapeSchema> backdrop(String name) =>
      rules.backdrops[name] ?? (throw ArtRulesError('unknown backdrop "$name"'));

  List<ShapeSchema> door(String name) => rules.doors[name] ?? (throw ArtRulesError('unknown door art "$name"'));

  Iterable<String> get backdropNames => rules.backdrops.keys;
  Iterable<String> get doorNames => rules.doors.keys;

  /// Every accent the file names, for the startup cross-check against theme.yml.
  Iterable<String> get accents => {
        for (final set in [...rules.backdrops.values, ...rules.doors.values])
          for (final s in set) s.accent,
        ...rules.poster.colors,
      };

  /// The same [seed] (a product id) always gives the same poster.
  PosterLook poster(String seed) {
    // A polynomial hash and a MINSTD generator, both mod 2^31 - 1: every product stays below 2^53, so the result
    // is the same on Android (64-bit ints) and on the web (JavaScript doubles). String.hashCode is not stable.
    const m = 2147483647;
    var h = 7;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) % m;
    }
    var state = h == 0 ? 1 : h;
    double next() {
      state = (state * 48271) % m;
      return state / m;
    }

    double pick(List<double> range) => range[0] + (range[1] - range[0]) * next();
    final colors = rules.poster.colors;
    final n = colors.length;
    final bg = h % n;
    final circle = (bg + 1 + (h ~/ n) % (n - 1)) % n;
    var bar = (bg + 1 + (h ~/ (n * n)) % (n - 1)) % n;
    if (bar == circle) bar = (circle + 1) % n == bg ? (circle + 2) % n : (circle + 1) % n;
    final p = rules.poster;
    return PosterLook(
      background: colors[bg],
      circleAccent: colors[circle],
      barAccent: colors[bar],
      circleSize: pick(p.circle.size),
      circleX: pick(p.circle.x),
      circleY: pick(p.circle.y),
      barThickness: p.bar.thickness,
      barY: pick(p.bar.y),
      barRotate: pick(p.bar.rotate),
    );
  }
}
