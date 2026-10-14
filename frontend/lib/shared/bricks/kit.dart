/// The parts bricks are drawn with: reading a brick's style from bricks.yml, text in a theme style, YAML icons,
/// the key-card press effect, artwork shapes and posters, and status tags. No sizes or colours live here: every
/// value comes from theme.yml, bricks.yml, icons.yml or art.yml.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../domain/ui/art_engine.dart';
import '../../domain/ui/icons_engine.dart';
import '../../domain/ui/theme_engine.dart';
import '../../schemas/ui/art_schema.dart';
import '../screens/screen_scope.dart';
import '../theme/app_theme.dart';

AppConfig configOf(BuildContext context) => ProviderScope.containerOf(context, listen: false).read(appConfigProvider);

/// One brick's `style:` block from bricks.yml, read through the theme.
class BrickStyle {
  final String brick;
  final Map<String, Object?> raw;
  final DesignTokens t;
  final TypeStyles type;
  BrickStyle._(this.brick, this.raw, this.t, this.type);

  factory BrickStyle.of(BuildContext context, String brick) =>
      BrickStyle._(brick, configOf(context).bricks.style(brick), context.tokens, context.type);

  Object _get(String key) => raw[key] ?? (throw StateError('bricks.yml: $brick.style.$key is missing'));

  String name(String key) => _get(key).toString();
  double number(String key) => (_get(key) as num).toDouble();
  double space(String key) => t.spacing(name(key));
  double radius(String key) => t.radius.named(name(key));
  TextStyle text(String key) => type.named(name(key));
  bool upper(String key) => type.isUpper(name(key));
  Color color(String key) => t.color(name(key));
  bool flag(String key) => _get(key) as bool;
  List<String> names(String key) => [for (final v in _get(key) as List) v.toString()];
}

/// Text in a theme style, in capitals when the style says `upper: true`.
class StyledText extends StatelessWidget {
  final String text;
  final String style;
  final Color? color;
  final TextAlign? align;
  final int? maxLines;
  const StyledText(this.text, {super.key, required this.style, this.color, this.align, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Text(
      type.isUpper(style) ? text.toUpperCase() : text,
      style: type.named(style).copyWith(color: color),
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// A strings.yml key, with `{placeholders}` filled from bindings ([args]: placeholder -> data path).
String say(BuildContext context, String key, {Map<String, String>? args, String? fallback}) {
  final strings = configOf(context).strings;
  if (args == null || args.isEmpty) return strings.get(key);
  final scope = BrickScope.of(context);
  final values = <String, Object>{};
  for (final MapEntry(key: name, value: path) in args.entries) {
    final v = scope.lookup(path);
    if (v == null || '$v'.isEmpty) return fallback != null ? strings.get(fallback) : strings.get(key, values);
    values[name] = v;
  }
  return strings.get(key, values);
}

/// An icon from icons.yml, stroked or filled in [color].
class YamlIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  final double? strokeWidth;
  const YamlIcon(this.name, {super.key, required this.size, required this.color, this.strokeWidth});

  @override
  Widget build(BuildContext context) {
    final icons = configOf(context).icons;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IconPainter(icons.shape(name), icons.viewBox, strokeWidth ?? icons.strokeWidth, color)),
    );
  }
}

class _IconPainter extends CustomPainter {
  final IconShape shape;
  final double viewBox, strokeWidth;
  final Color color;
  _IconPainter(this.shape, this.viewBox, this.strokeWidth, this.color);

  Path _path(List<PathCommand> cmds) {
    final p = Path();
    for (final c in cmds) {
      switch (c) {
        case MoveTo(:final x, :final y):
          p.moveTo(x, y);
        case LineTo(:final x, :final y):
          p.lineTo(x, y);
        case CubicTo(:final x1, :final y1, :final x2, :final y2, :final x, :final y):
          p.cubicTo(x1, y1, x2, y2, x, y);
        case QuadTo(:final x1, :final y1, :final x, :final y):
          p.quadraticBezierTo(x1, y1, x, y);
        case ClosePath():
          p.close();
      }
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / viewBox, size.height / viewBox);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final fill = Paint()..color = color;
    for (final cmds in shape.stroke) {
      canvas.drawPath(_path(cmds), stroke);
    }
    for (final cmds in shape.fill) {
      canvas.drawPath(_path(cmds), fill);
    }
    for (final c in shape.circles) {
      canvas.drawCircle(Offset(c.cx, c.cy), c.r, stroke);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.shape != shape || old.color != color || old.strokeWidth != strokeWidth || old.viewBox != viewBox;
}

/// The key-card press effect: rises on hover and focus, sinks a little on press, and casts the lift shadow in
/// [accent]. A button for screen readers and the keyboard.
class Pressable extends StatefulWidget {
  final Widget Function(BuildContext context, bool active) builder;
  final VoidCallback? onTap;
  final Color accent;
  final double? lift;
  final String? semanticLabel;
  const Pressable({super.key, required this.builder, required this.accent, this.onTap, this.lift, this.semanticLabel});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hover = false, _focus = false, _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final active = widget.onTap != null && (_hover || _focus || _down);
    final rise = reduced || !active ? 0.0 : (widget.lift ?? t.hoverLift);
    final scale = reduced || !_down ? 1.0 : t.pressScale;
    final duration = reduced ? t.fast * t.reducedMotionFactor : t.fast;
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: widget.onTap != null,
        mouseCursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: duration,
            curve: curveOf(t.curves['out']!),
            transform: Matrix4.translationValues(0, -rise, 0)..scaleByDouble(scale, scale, 1, 1),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(boxShadow: active ? boxShadows(t.lift(widget.accent)) : const []),
            foregroundDecoration: _focus
                ? BoxDecoration(border: Border.all(color: t.tone(t.focusRingTone).line, width: t.focusRingWidth))
                : null,
            child: widget.builder(context, active),
          ),
        ),
      ),
    );
  }
}

/// Shapes from art.yml (a backdrop or door art), placed in pixels from the box edges.
class ArtShapes extends StatelessWidget {
  final List<ShapeSchema> shapes;
  const ArtShapes(this.shapes, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IgnorePointer(
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        for (final s in shapes)
          Positioned(
            left: s.left,
            right: s.right,
            top: s.top,
            bottom: s.bottom,
            child: Transform.rotate(
              angle: s.rotate * math.pi / 180,
              child: Container(
                width: s.shape == ShapeKind.bar ? s.w : s.size,
                height: s.shape == ShapeKind.bar ? s.h : s.size,
                decoration: BoxDecoration(
                  color: t.accent(s.accent).fill.withValues(alpha: s.opacity),
                  shape: s.shape == ShapeKind.circle ? BoxShape.circle : BoxShape.rectangle,
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// A product poster from art.yml's generator: background, circle and slanted bar, stable per [seed].
class PosterArt extends StatelessWidget {
  final String seed;
  const PosterArt(this.seed, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final look = configOf(context).art.poster(seed);
    return CustomPaint(painter: _PosterPainter(look, t), child: const SizedBox.expand());
  }
}

class _PosterPainter extends CustomPainter {
  final PosterLook look;
  final DesignTokens t;
  _PosterPainter(this.look, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    canvas.clipRect(box);
    canvas.drawRect(box, Paint()..color = t.accent(look.background).fill);
    final d = look.circleSize * size.width;
    canvas.drawCircle(
      Offset(look.circleX * size.width + d / 2, look.circleY * size.height + d / 2),
      d / 2,
      Paint()..color = t.accent(look.circleAccent).fill,
    );
    canvas.save();
    final barH = look.barThickness * size.height;
    canvas.translate(size.width / 2, look.barY * size.height + barH / 2);
    canvas.rotate(look.barRotate * math.pi / 180);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: size.width * 1.4, height: barH),
        Paint()..color = t.accent(look.barAccent).fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PosterPainter old) => old.look != look || old.t != t;
}

/// A product's picture: its thumbnail when it has one, else (and while it loads, or if it fails) the art.yml
/// poster for [seed]. Images only: video never loads here.
class Poster extends StatelessWidget {
  final String seed;
  final String? thumbnailUrl;
  const Poster({super.key, required this.seed, this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    final art = PosterArt(seed);
    if (thumbnailUrl == null) return art;
    return Image.network(
      thumbnailUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => art,
      frameBuilder: (_, child, frame, sync) => frame == null && !sync ? art : child,
    );
  }
}

/// The CraftStream mark: three slanted stripes, one per accent in [accents].
class Stripes extends StatelessWidget {
  final double size;
  final List<String> accents;
  const Stripes({super.key, required this.size, required this.accents});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _StripesPainter([for (final a in accents) t.accent(a).fill])),
    );
  }
}

class _StripesPainter extends CustomPainter {
  final List<Color> colors;
  _StripesPainter(this.colors);

  // Artwork geometry on a 24-unit grid: each stripe is a parallelogram leaning right, as on the design canvas.
  static const _grid = 24.0, _step = 6.5, _top = 2.0, _bottom = 22.0, _lean = 6.0, _thick = 4.0, _start = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _grid, size.height / _grid);
    for (final (i, c) in colors.indexed) {
      final x = _start + i * _step;
      canvas.drawPath(
        Path()
          ..moveTo(x, _bottom)
          ..lineTo(x + _lean, _top)
          ..lineTo(x + _lean + _thick, _top)
          ..lineTo(x + _thick, _bottom)
          ..close(),
        Paint()..color = c,
      );
    }
  }

  @override
  bool shouldRepaint(_StripesPainter old) => old.colors != colors;
}

/// A small filled tag for a status from status.yml (`PLACED`, `LIVE` …) in text style [style].
class StatusTag extends StatelessWidget {
  final String kind, value, style;
  const StatusTag({super.key, required this.kind, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    final config = configOf(context);
    final t = context.tokens;
    final look = config.status.look(kind, value);
    final tone = t.tone(look.tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.xs + t.space.xxs, vertical: t.space.xxs),
      color: tone.fill,
      child: StyledText(config.strings.get(look.label), style: style, color: tone.onFill, maxLines: 1),
    );
  }
}
