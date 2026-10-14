/// Icons from icons.yml, parsed once into absolute drawing commands. Pure Dart: the icon brick replays the
/// commands on a canvas.
library;

import '../../schemas/ui/icons_schema.dart';

class IconsRulesError implements Exception {
  final String message;
  const IconsRulesError(this.message);
  @override
  String toString() => 'icons.yml: $message';
}

sealed class PathCommand {
  const PathCommand();
}

class MoveTo extends PathCommand {
  final double x, y;
  const MoveTo(this.x, this.y);
}

class LineTo extends PathCommand {
  final double x, y;
  const LineTo(this.x, this.y);
}

class CubicTo extends PathCommand {
  final double x1, y1, x2, y2, x, y;
  const CubicTo(this.x1, this.y1, this.x2, this.y2, this.x, this.y);
}

class QuadTo extends PathCommand {
  final double x1, y1, x, y;
  const QuadTo(this.x1, this.y1, this.x, this.y);
}

class ClosePath extends PathCommand {
  const ClosePath();
}

class IconCircle {
  final double cx, cy, r;
  const IconCircle(this.cx, this.cy, this.r);
}

/// One icon, ready to draw on a [viewBox]-sized grid.
class IconShape {
  final List<List<PathCommand>> stroke, fill;
  final List<IconCircle> circles;
  const IconShape(this.stroke, this.fill, this.circles);
}

final _token = RegExp(r'[MmLlHhVvCcQqZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

/// SVG path data -> absolute commands. Supports M L H V C Q Z (and lower-case relative forms), with implicit
/// repeats (`l1 2 3 4`) the way SVG allows.
List<PathCommand> parsePath(String d, String where) {
  final tokens = _token.allMatches(d).map((m) => m.group(0)!).toList();
  final out = <PathCommand>[];
  var i = 0;
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  String? cmd;
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double num() {
    if (i >= tokens.length || isCmd(tokens[i])) throw IconsRulesError('$where: path "$d" is missing a number');
    return double.parse(tokens[i++]);
  }

  while (i < tokens.length) {
    if (isCmd(tokens[i])) {
      cmd = tokens[i++];
    } else if (cmd == null) {
      throw IconsRulesError('$where: path "$d" must start with a command');
    }
    final rel = cmd.toLowerCase() == cmd && cmd != 'z';
    final dx = rel ? x : 0.0, dy = rel ? y : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = num() + dx;
        y = num() + dy;
        startX = x;
        startY = y;
        out.add(MoveTo(x, y));
        cmd = rel ? 'l' : 'L'; // further pairs after M are line-tos
      case 'L':
        x = num() + dx;
        y = num() + dy;
        out.add(LineTo(x, y));
      case 'H':
        x = num() + dx;
        out.add(LineTo(x, y));
      case 'V':
        y = num() + dy;
        out.add(LineTo(x, y));
      case 'C':
        final x1 = num() + dx, y1 = num() + dy, x2 = num() + dx, y2 = num() + dy;
        x = num() + dx;
        y = num() + dy;
        out.add(CubicTo(x1, y1, x2, y2, x, y));
      case 'Q':
        final x1 = num() + dx, y1 = num() + dy;
        x = num() + dx;
        y = num() + dy;
        out.add(QuadTo(x1, y1, x, y));
      case 'Z':
        x = startX;
        y = startY;
        out.add(const ClosePath());
        cmd = null;
      default:
        throw IconsRulesError('$where: unsupported path command "$cmd" (use M L H V C Q Z)');
    }
  }
  if (out.isEmpty || out.first is! MoveTo) throw IconsRulesError('$where: path "$d" must start with M');
  return out;
}

class IconsEngine {
  final IconsSchema rules;
  final Map<String, IconShape> _shapes = {};

  /// Parses every icon up front, so a broken path fails at startup with the icon's name.
  IconsEngine(this.rules) {
    if (rules.viewBox <= 0 || rules.strokeWidth <= 0) {
      throw const IconsRulesError('view_box and stroke_width must be positive');
    }
    rules.icons.forEach((name, icon) {
      if (icon.stroke.isEmpty && icon.fill.isEmpty && icon.circles.isEmpty) {
        throw IconsRulesError('$name has nothing to draw');
      }
      for (final c in icon.circles) {
        if (c.length != 3 || c[2] <= 0) throw IconsRulesError('$name: circles are [cx, cy, r] with r > 0');
      }
      _shapes[name] = IconShape(
        [for (final d in icon.stroke) parsePath(d, name)],
        [for (final d in icon.fill) parsePath(d, name)],
        [for (final c in icon.circles) IconCircle(c[0], c[1], c[2])],
      );
    });
  }

  Iterable<String> get names => _shapes.keys;

  bool has(String name) => _shapes.containsKey(name);

  IconShape shape(String name) => _shapes[name] ?? (throw IconsRulesError('unknown icon "$name"'));

  double get viewBox => rules.viewBox;
  double get strokeWidth => rules.strokeWidth;
}
