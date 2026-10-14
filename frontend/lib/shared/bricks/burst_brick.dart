/// The `burst` brick: a one-shot celebration behind its item, like the client portal's celebration_burst
/// (mo-confetti). Small squares in the accent colours fly out from the centre, turn and fade. Every number comes from
/// the brick's style in bricks.yml; when the device asks for less motion only the item shows.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/ui/bricks_engine.dart';
import '../theme/app_theme.dart';
import 'bricks.dart';
import 'kit.dart';

Widget burstBrick(BuildContext context, BrickNode n) => _Burst(n);

class _Burst extends StatefulWidget {
  final BrickNode n;
  const _Burst(this.n);

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null || MediaQuery.disableAnimationsOf(context)) return;
    final s = BrickStyle.of(context, 'burst');
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: s.number('duration_ms').toInt()))..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = buildBrick(context, widget.n.need<BrickNode>('item'));
    final c = _c;
    if (c == null) return item;
    final s = BrickStyle.of(context, 'burst');
    final t = context.tokens;
    final distance = s.raw['distance'] as List;
    return Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
      item,
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: c,
            builder: (context, _) => CustomPaint(
              painter: _Pieces(
                progress: curveOf(t.curves['out']!).transform(c.value),
                count: s.number('pieces').toInt(),
                size: s.number('piece'),
                near: (distance[0] as num).toDouble(),
                far: (distance[1] as num).toDouble(),
                spin: s.number('spin'),
                colors: [for (final a in s.names('accents')) t.accent(a).fill],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Pieces extends CustomPainter {
  final double progress, size, near, far, spin;
  final int count;
  final List<Color> colors;
  _Pieces({
    required this.progress,
    required this.count,
    required this.size,
    required this.near,
    required this.far,
    required this.spin,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size box) {
    if (progress >= 1) return;
    // The burst starts at the item's centre (the mark sits at the left of its row).
    final origin = Offset(math.min(box.width, box.height) / 2, box.height / 2);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      // Even spread around the circle with a fixed wobble per piece, so every burst looks the same.
      final angle = 2 * math.pi * i / count + (i.isEven ? 0.2 : -0.15);
      final reach = near + (far - near) * ((i * 37) % count) / count;
      final at = origin + Offset(math.cos(angle), math.sin(angle)) * reach * progress;
      paint.color = colors[i % colors.length].withValues(alpha: 1 - progress);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(spin * math.pi / 180 * progress);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: size, height: size), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Pieces old) => old.progress != progress;
}
