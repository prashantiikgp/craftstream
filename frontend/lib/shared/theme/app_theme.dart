/// Turns resolved DesignTokens into Flutter's ThemeData, and gives widgets typed access to every token:
///
///   final t = context.tokens;          // colours, spacing, radius, shadows, motion
///   Text('₹450', style: context.type.price);
library;

import 'package:flutter/material.dart';

import '../../domain/ui/theme_engine.dart';

/// Text styles from the type scale, coloured with `text` by default. Bricks look styles up by their theme.yml
/// name with [named]; the fields feed Material's text theme.
class TypeStyles {
  final TextStyle display, h1, h2, h3, title, body, bodyStrong, label, caption, price;
  final Map<String, TextStyle> _all;
  final Set<String> _upper;
  const TypeStyles._(this._all, this._upper, {
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
    final all = {
      for (final MapEntry(key: name, value: spec) in t.styles.entries)
        name: TextStyle(
          fontFamily: spec.family,
          fontSize: spec.size,
          fontWeight: spec.weight,
          height: spec.height,
          letterSpacing: spec.letterSpacing,
          color: t.text,
        ),
    };
    final upper = {for (final e in t.styles.entries) if (e.value.upper) e.key};
    return TypeStyles._(
      all, upper,
      display: all['display']!, h1: all['h1']!, h2: all['h2']!, h3: all['h3']!, title: all['title']!,
      body: all['body']!, bodyStrong: all['body_strong']!, label: all['label']!, caption: all['caption']!,
      price: all['price']!,
    );
  }

  /// A style by its theme.yml name (`eyebrow`, `price_sm` …).
  TextStyle named(String name) =>
      _all[name] ?? (throw ArgumentError('unknown text style "$name" (have: ${_all.keys.join(', ')})'));

  bool has(String name) => _all.containsKey(name);

  /// Whether theme.yml shows this style in capitals (`upper: true`).
  bool isUpper(String name) => _upper.contains(name);
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
  // Material's own widgets (text fields, menus, progress) take theme B tones: brand for primary, info for
  // secondary, danger for errors.
  final brand = t.tone('brand'), info = t.tone('info'), danger = t.tone('danger');
  final scheme = ColorScheme(
    brightness: t.brightness,
    primary: brand.fill,
    onPrimary: brand.onFill,
    primaryContainer: brand.wash,
    onPrimaryContainer: brand.ink,
    secondary: info.fill,
    onSecondary: info.onFill,
    secondaryContainer: info.wash,
    onSecondaryContainer: info.ink,
    tertiary: info.fill,
    onTertiary: brand.onFill,
    error: danger.fill,
    onError: brand.onFill,
    errorContainer: danger.wash,
    onErrorContainer: danger.ink,
    surface: t.surface,
    onSurface: t.text,
    onSurfaceVariant: t.textMuted,
    surfaceContainerLowest: t.surface,
    surfaceContainerLow: t.ground,
    surfaceContainer: t.surfaceAlt,
    surfaceContainerHigh: t.surfaceAlt,
    surfaceContainerHighest: t.line,
    outline: t.line,
    outlineVariant: t.line,
    shadow: t.scrim,
    scrim: t.scrim,
    inverseSurface: t.text,
    onInverseSurface: t.ground,
    inversePrimary: brand.wash,
  );
  final radiusMd = BorderRadius.circular(t.radius.card);
  final radiusSm = BorderRadius.circular(t.radius.sharp);
  return ThemeData(
    useMaterial3: true,
    brightness: t.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.ground,
    canvasColor: t.ground,
    fontFamily: type.body.fontFamily,
    dividerColor: t.line,
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
      bodySmall: type.caption.copyWith(color: t.textMuted),
      labelLarge: type.label,
      labelMedium: type.caption,
      labelSmall: type.caption,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.ground,
      foregroundColor: t.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: type.h3,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radiusMd, side: BorderSide(color: t.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surface,
      hintStyle: type.body.copyWith(color: t.textFaint),
      labelStyle: type.label.copyWith(color: t.textMuted),
      contentPadding: EdgeInsets.symmetric(horizontal: t.space.lg, vertical: t.space.md),
      border: OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: t.line)),
      enabledBorder: OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: t.line)),
      focusedBorder: OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: brand.fill, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: danger.fill)),
      focusedErrorBorder:
          OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: danger.fill, width: 2)),
      errorStyle: type.caption.copyWith(color: danger.ink),
      helperStyle: type.caption.copyWith(color: t.textMuted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      indicatorColor: brand.wash,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(type.caption),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: t.surface,
      indicatorColor: brand.wash,
      selectedIconTheme: IconThemeData(color: brand.ink),
      unselectedIconTheme: IconThemeData(color: t.textMuted),
      selectedLabelTextStyle: type.caption.copyWith(color: brand.ink),
      unselectedLabelTextStyle: type.caption.copyWith(color: t.textMuted),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.text,
      contentTextStyle: type.body.copyWith(color: t.ground),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radiusSm),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand.wash : t.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand.ink : t.text),
        side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(color: s.contains(WidgetState.selected) ? brand.line : t.line)),
        textStyle: WidgetStatePropertyAll(type.label),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: brand.fill, linearTrackColor: brand.wash),
    iconTheme: IconThemeData(color: t.text, size: 20),
  );
}
