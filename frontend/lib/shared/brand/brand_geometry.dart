/// The CraftStream mark as data: a thrown clay vessel with a play triangle cut out of its belly, standing on a
/// potter's wheel. One definition feeds the Flutter painters, the SVG sources and the Android vector icon, so the
/// three can never drift apart (test/shared/brand/brand_assets_test.dart checks the written files are fresh).
///
/// Coordinates live in a 100 × 100 box.
library;

import 'dart:math' as math;
import 'dart:ui';

/// One path command. Only the subset SVG, Android VectorDrawable and dart:ui all share: M, L, Q, C, Z.
sealed class PathCmd {
  const PathCmd();
}

class MoveTo extends PathCmd {
  final double x, y;
  const MoveTo(this.x, this.y);
}

class LineTo extends PathCmd {
  final double x, y;
  const LineTo(this.x, this.y);
}

class QuadTo extends PathCmd {
  final double cx, cy, x, y;
  const QuadTo(this.cx, this.cy, this.x, this.y);
}

class CubicTo extends PathCmd {
  final double c1x, c1y, c2x, c2y, x, y;
  const CubicTo(this.c1x, this.c1y, this.c2x, this.c2y, this.x, this.y);
}

class ClosePath extends PathCmd {
  const ClosePath();
}

/// Vessel outline (clockwise from the left of the rim).
const List<PathCmd> vesselCmds = [
  MoveTo(30, 11),
  LineTo(70, 11),
  CubicTo(72, 15, 66, 17, 64, 21), // lip flares into the neck
  CubicTo(62, 26, 88, 34, 88, 56), // shoulder swells to the belly
  CubicTo(88, 76, 76, 88, 66, 90), // belly tucks into the foot
  LineTo(34, 90),
  CubicTo(24, 88, 12, 76, 12, 56),
  CubicTo(12, 34, 38, 26, 36, 21),
  CubicTo(34, 17, 28, 15, 30, 11),
  ClosePath(),
];

/// Play triangle in the belly, optically centred (a triangle's visual centre sits left of its box centre).
final List<PathCmd> playCmds = roundedPolygon(const [Offset(41, 42), Offset(41, 72), Offset(67, 57)], 3.2);

/// The wheel head under the vessel: a pill.
final List<PathCmd> wheelCmds = roundedRect(const Rect.fromLTRB(14, 93, 86, 98.5), 2.75);

/// Vessel with the triangle as a hole (even-odd fill), so the mark works on any background.
List<PathCmd> markCmds({bool wheel = true}) => [...vesselCmds, ...playCmds, if (wheel) ...wheelCmds];

/// A polygon with circular-ish rounded corners (quadratic joins), as path commands.
List<PathCmd> roundedPolygon(List<Offset> pts, double r) {
  final cmds = <PathCmd>[];
  for (var i = 0; i < pts.length; i++) {
    final prev = pts[(i - 1 + pts.length) % pts.length], v = pts[i], next = pts[(i + 1) % pts.length];
    final a = v + _unit(prev - v) * r, b = v + _unit(next - v) * r;
    cmds.add(i == 0 ? MoveTo(_r(a.dx), _r(a.dy)) : LineTo(_r(a.dx), _r(a.dy)));
    cmds.add(QuadTo(v.dx, v.dy, _r(b.dx), _r(b.dy)));
  }
  return [...cmds, const ClosePath()];
}

List<PathCmd> roundedRect(Rect rect, double r) {
  final l = rect.left, t = rect.top, rr = rect.right, b = rect.bottom;
  return [
    MoveTo(l + r, t),
    LineTo(rr - r, t),
    QuadTo(rr, t, rr, t + r),
    LineTo(rr, b - r),
    QuadTo(rr, b, rr - r, b),
    LineTo(l + r, b),
    QuadTo(l, b, l, b - r),
    LineTo(l, t + r),
    QuadTo(l, t, l + r, t),
    const ClosePath(),
  ];
}

Offset _unit(Offset o) => o / o.distance;
double _r(double v) => (v * 100).roundToDouble() / 100;

/// Build a dart:ui Path, mapping the 100-unit box onto [rect].
Path toPath(List<PathCmd> cmds, Rect rect, {bool evenOdd = true}) {
  final sx = rect.width / 100, sy = rect.height / 100;
  double x(double v) => rect.left + v * sx;
  double y(double v) => rect.top + v * sy;
  final p = Path()..fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
  for (final c in cmds) {
    switch (c) {
      case MoveTo():
        p.moveTo(x(c.x), y(c.y));
      case LineTo():
        p.lineTo(x(c.x), y(c.y));
      case QuadTo():
        p.quadraticBezierTo(x(c.cx), y(c.cy), x(c.x), y(c.y));
      case CubicTo():
        p.cubicTo(x(c.c1x), y(c.c1y), x(c.c2x), y(c.c2y), x(c.x), y(c.y));
      case ClosePath():
        p.close();
    }
  }
  return p;
}

/// SVG / VectorDrawable path data, mapping the 100-unit box to [scale] units starting at ([dx], [dy]).
String toPathData(List<PathCmd> cmds, {double scale = 1, double dx = 0, double dy = 0}) {
  String n(double v) {
    final s = (v * 1000).round() / 1000;
    return s == s.roundToDouble() ? s.toInt().toString() : s.toString();
  }

  String px(double v) => n(dx + v * scale);
  String py(double v) => n(dy + v * scale);
  return cmds.map((c) => switch (c) {
        MoveTo() => 'M${px(c.x)} ${py(c.y)}',
        LineTo() => 'L${px(c.x)} ${py(c.y)}',
        QuadTo() => 'Q${px(c.cx)} ${py(c.cy)} ${px(c.x)} ${py(c.y)}',
        CubicTo() => 'C${px(c.c1x)} ${py(c.c1y)} ${px(c.c2x)} ${py(c.c2y)} ${px(c.x)} ${py(c.y)}',
        ClosePath() => 'Z',
      }).join(' ');
}

/// Angle helper for the illustrations.
double deg(double d) => d * math.pi / 180;
