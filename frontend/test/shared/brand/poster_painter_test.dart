// The poster texture loops step by a fraction of the poster's size: degenerate sizes must still finish.
import 'dart:ui';

import 'package:craftstream/shared/brand/brand_painters.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';

void paintPoster(PosterMotif motif, Size size) {
  final recorder = PictureRecorder();
  PosterPainter(motif: motif, wash: Colors.white, accent: Colors.orange, disc: Colors.white)
      .paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

void main() {
  const sizes = [Size.zero, Size(1, 1), Size(1000, 0.001), Size(0.001, 1000), Size(320, 0), Size(0, 180)];

  for (final motif in PosterMotif.values) {
    test('${motif.name} poster paints at degenerate sizes', () {
      for (final size in sizes) {
        paintPoster(motif, size);
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('${motif.name} poster still paints its texture at the smallest textured size', () {
      paintPoster(motif, const Size(PosterPainter.minTextureSide, PosterPainter.minTextureSide));
      paintPoster(motif, const Size(320, 180));
    }, timeout: const Timeout(Duration(seconds: 10)));
  }
}
