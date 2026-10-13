/// Buttons. Primary = brand fill (one per screen), secondary = outlined, ghost = text only, danger = destructive.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum ButtonVariant { primary, secondary, ghost, danger }

enum ButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed; // null = disabled
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;

  const AppButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final height = switch (size) { ButtonSize.sm => 36.0, ButtonSize.md => 44.0, ButtonSize.lg => 52.0 };
    final pad = switch (size) { ButtonSize.sm => t.space.md, ButtonSize.md => t.space.lg, ButtonSize.lg => t.space.xl };
    final (bg, fg, hover, border) = switch (variant) {
      ButtonVariant.primary => (t.brand, t.onBrand, t.brandD, null),
      ButtonVariant.secondary => (t.card, t.ink, t.brandLl, t.hair),
      ButtonVariant.ghost => (Colors.transparent, t.brandInk, t.brandLl, null),
      ButtonVariant.danger => (t.danger.wash, t.danger.ink, t.danger.border, null),
    };
    final enabled = onPressed != null && !loading;
    final looksEnabled = onPressed != null; // a loading button keeps its colour
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(expand ? double.infinity : 0, height)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: pad)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radius.sm))),
      side: WidgetStatePropertyAll(border == null ? BorderSide.none : BorderSide(color: border)),
      textStyle: WidgetStatePropertyAll(size == ButtonSize.sm ? context.type.caption : context.type.label),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (!looksEnabled) return variant == ButtonVariant.primary ? t.hair : bg;
        if (variant == ButtonVariant.primary && s.contains(WidgetState.pressed)) return t.brandDd;
        if (s.contains(WidgetState.hovered)) return hover;
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((s) => looksEnabled ? fg : t.faint),
      overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: 0.08)),
      animationDuration: t.fast,
    );
    final child = loading
        ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18), SizedBox(width: t.space.sm)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ]);
    return Semantics(
      button: true,
      enabled: enabled,
      child: TextButton(onPressed: looksEnabled ? (loading ? () {} : onPressed) : null, style: style, child: child),
    );
  }
}
