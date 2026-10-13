/// Surfaces: AppCard (only a shell: surface, border, radius, elevation), SectionHeader, Notice, EmptyState, Skeleton.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tone.dart';

enum CardVariant { flat, elevated, interactive }

class AppCard extends StatefulWidget {
  final Widget child;
  final CardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  const AppCard({super.key, required this.child, this.variant = CardVariant.flat, this.onTap, this.padding});

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lifted = widget.variant == CardVariant.elevated || (widget.variant == CardVariant.interactive && _hover);
    final radius = BorderRadius.circular(t.radius.md);
    final body = AnimatedContainer(
      duration: t.fast,
      curve: curveOf(t.curves['out']!),
      padding: widget.padding ?? EdgeInsets.all(t.space.lg),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: radius,
        border: Border.all(color: _hover ? t.brandLine : t.hair),
        boxShadow: lifted ? boxShadows(_hover ? t.shadowLg : t.shadowSm) : null,
      ),
      child: widget.child,
    );
    if (widget.onTap == null) return body;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: radius, onTap: widget.onTap, child: body),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionHeader(this.title, {super.key, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.type.h3),
            if (subtitle != null) ...[
              SizedBox(height: t.space.xxs),
              Text(subtitle!, style: context.type.body.copyWith(color: t.sub)),
            ],
          ]),
        ),
        ?action,
      ]),
    );
  }
}

class Notice extends StatelessWidget {
  final Tone tone;
  final String title;
  final String? message;
  final IconData? icon;
  const Notice({super.key, required this.tone, required this.title, this.message, this.icon});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = toneColors(t, tone);
    final defaultIcon = switch (tone) {
      Tone.success => Icons.check_circle_outline,
      Tone.danger => Icons.error_outline,
      Tone.warning => Icons.warning_amber_rounded,
      _ => Icons.info_outline,
    };
    return Semantics(
      liveRegion: tone == Tone.danger,
      child: Container(
        padding: EdgeInsets.all(t.space.md),
        decoration: BoxDecoration(
          color: c.wash,
          borderRadius: BorderRadius.circular(t.radius.sm),
          border: Border.all(color: c.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon ?? defaultIcon, color: c.ink, size: 20),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.type.label.copyWith(color: c.ink)),
              if (message != null) ...[
                SizedBox(height: t.space.xxs),
                Text(message!, style: context.type.body.copyWith(color: c.ink)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.all(t.space.xxl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: EdgeInsets.all(t.space.lg),
          decoration: BoxDecoration(color: t.brandLl, shape: BoxShape.circle),
          child: Icon(icon, size: 32, color: t.brandInk),
        ),
        SizedBox(height: t.space.lg),
        Text(title, style: context.type.h3, textAlign: TextAlign.center),
        SizedBox(height: t.space.xs),
        Text(message, style: context.type.body.copyWith(color: t.sub), textAlign: TextAlign.center),
        if (action != null) ...[SizedBox(height: t.space.lg), action!],
      ]),
    );
  }
}

/// Placeholder block while data loads (a soft pulse, no spinner, so layouts don't jump).
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double? radius;
  const Skeleton({super.key, this.width, required this.height, this.radius});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: t.surfaceSoft,
          borderRadius: BorderRadius.circular(widget.radius ?? t.radius.sm),
        ),
      ),
    );
  }
}
