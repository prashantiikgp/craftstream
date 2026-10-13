/// Turns resolved DesignTokens into Flutter's ThemeData, and gives widgets typed access to every token:
///
///   final t = context.tokens;          // colours, spacing, radius, shadows, motion
///   Text('₹450', style: context.type.price);
library;

import 'package:flutter/material.dart';

import '../../domain/ui/theme_engine.dart';

/// Text styles from the type scale, coloured with `ink` by default.
class TypeStyles {
  final TextStyle display, h1, h2, h3, title, body, bodyStrong, label, caption, price;
  const TypeStyles({
    required this.display,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.title,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
    required this.price,
  });

  factory TypeStyles.from(DesignTokens t) {
    TextStyle s(String name) {
      final spec = t.text[name]!;
      return TextStyle(
        fontFamily: spec.family,
        fontSize: spec.size,
        fontWeight: spec.weight,
        height: spec.height,
        letterSpacing: spec.letterSpacing,
        color: t.ink,
      );
    }

    return TypeStyles(
      display: s('display'), h1: s('h1'), h2: s('h2'), h3: s('h3'), title: s('title'), body: s('body'),
      bodyStrong: s('body_strong'), label: s('label'), caption: s('caption'), price: s('price'),
    );
  }
}

class AppTokens extends ThemeExtension<AppTokens> {
  final DesignTokens tokens;
  final TypeStyles styles;
  AppTokens(this.tokens) : styles = TypeStyles.from(tokens);

  @override
  AppTokens copyWith({DesignTokens? tokens}) => AppTokens(tokens ?? this.tokens);

  @override
  AppTokens lerp(covariant AppTokens? other, double t) => t < 0.5 || other == null ? this : other;
}

extension TokensContext on BuildContext {
  DesignTokens get tokens => Theme.of(this).extension<AppTokens>()!.tokens;
  TypeStyles get type => Theme.of(this).extension<AppTokens>()!.styles;
}

List<BoxShadow> boxShadows(List<ShadowSpec> specs) => [
      for (final s in specs) BoxShadow(offset: s.offset, blurRadius: s.blur, spreadRadius: s.spread, color: s.color),
    ];

Curve curveOf(List<double> p) => Cubic(p[0], p[1], p[2], p[3]);

ThemeData buildTheme(DesignTokens t) {
  final ext = AppTokens(t);
  final type = ext.styles;
  final scheme = ColorScheme(
    brightness: t.brightness,
    primary: t.brand,
    onPrimary: t.onBrand,
    primaryContainer: t.brandL,
    onPrimaryContainer: t.brandInk,
    secondary: t.secondary,
    onSecondary: t.onSecondary,
    secondaryContainer: t.secondaryL,
    onSecondaryContainer: t.secondaryInk,
    tertiary: t.info.fill,
    onTertiary: t.onBrand,
    error: t.danger.fill,
    onError: t.onBrand,
    errorContainer: t.danger.wash,
    onErrorContainer: t.danger.ink,
    surface: t.card,
    onSurface: t.ink,
    onSurfaceVariant: t.sub,
    surfaceContainerLowest: t.card,
    surfaceContainerLow: t.bg,
    surfaceContainer: t.surfaceSoft,
    surfaceContainerHigh: t.surfaceSoft,
    surfaceContainerHighest: t.hairSoft,
    outline: t.hair,
    outlineVariant: t.hairSoft,
    shadow: t.scrim,
    scrim: t.scrim,
    inverseSurface: t.ink,
    onInverseSurface: t.bg,
    inversePrimary: t.brandL,
  );
  final radiusMd = BorderRadius.circular(t.radius.md);
  final radiusSm = BorderRadius.circular(t.radius.sm);
  return ThemeData(
    useMaterial3: true,
    brightness: t.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.bg,
    fontFamily: type.body.fontFamily,
    dividerColor: t.hair,
    splashFactory: InkSparkle.splashFactory,
    extensions: [ext],
    textTheme: TextTheme(
      displaySmall: type.display,
      headlineLarge: type.h1,
      headlineMedium: type.h2,
      headlineSmall: type.h3,
      titleLarge: type.h3,
      titleMedium: type.title,
      titleSmall: type.label,
      bodyLarge: type.bodyStrong,
      bodyMedium: type.body,
      bodySmall: type.caption.copyWith(color: t.sub),
      labelLarge: type.label,
      labelMedium: type.caption,
      labelSmall: type.caption,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: type.h3,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: t.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radiusMd, side: BorderSide(color: t.hair)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.card,
      hintStyle: type.body.copyWith(color: t.faint),
      labelStyle: type.label.copyWith(color: t.sub),
      contentPadding: EdgeInsets.symmetric(horizontal: t.space.lg, vertical: t.space.md),
      border: OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: t.hair)),
      enabledBorder: OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: t.hair)),
      focusedBorder: OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: t.brand, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: t.danger.fill)),
      focusedErrorBorder:
          OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: t.danger.fill, width: 2)),
      errorStyle: type.caption.copyWith(color: t.danger.ink),
      helperStyle: type.caption.copyWith(color: t.sub),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.card,
      indicatorColor: t.brandLl,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(type.caption),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: t.card,
      indicatorColor: t.brandLl,
      selectedIconTheme: IconThemeData(color: t.brandInk),
      unselectedIconTheme: IconThemeData(color: t.sub),
      selectedLabelTextStyle: type.caption.copyWith(color: t.brandInk),
      unselectedLabelTextStyle: type.caption.copyWith(color: t.sub),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.ink,
      contentTextStyle: type.body.copyWith(color: t.bg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radiusSm),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.brandLl : t.card),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.brandInk : t.ink),
        side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(color: s.contains(WidgetState.selected) ? t.brandLine : t.hair)),
        textStyle: WidgetStatePropertyAll(type.label),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.brand, linearTrackColor: t.brandL),
    iconTheme: IconThemeData(color: t.ink, size: 20),
  );
}
