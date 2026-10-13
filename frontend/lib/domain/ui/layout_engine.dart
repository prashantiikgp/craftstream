/// Size classes and grid maths from layout.yml. Pure Dart: screens pass a width, get back decisions.
library;

import 'dart:math' as math;

import '../../schemas/ui/layout_schema.dart';

class LayoutRulesError implements Exception {
  final String message;
  const LayoutRulesError(this.message);
  @override
  String toString() => 'layout.yml: $message';
}

class LayoutEngine {
  final LayoutSchema rules;

  /// Validates: classes start at 0, grow strictly, have unique names and sane numbers.
  LayoutEngine(this.rules) {
    final classes = rules.sizeClasses;
    if (classes.isEmpty || classes.first.minWidth != 0) {
      throw const LayoutRulesError('size_classes must start with min_width: 0');
    }
    for (var i = 1; i < classes.length; i++) {
      if (classes[i].minWidth <= classes[i - 1].minWidth) {
        throw LayoutRulesError('size_classes must be in increasing min_width order (${classes[i].name})');
      }
    }
    if (classes.map((c) => c.name).toSet().length != classes.length) {
      throw const LayoutRulesError('size class names must be unique');
    }
    for (final c in classes) {
      if (c.gridColumns < 1) throw LayoutRulesError('${c.name}.grid_columns must be at least 1');
    }
    if (rules.sideBySideVideoFraction <= 0 || rules.sideBySideVideoFraction >= 1) {
      throw const LayoutRulesError('side_by_side_video_fraction must be between 0 and 1');
    }
  }

  List<String> get sizeClassNames => [for (final c in rules.sizeClasses) c.name];

  SizeClassSchema sizeClassFor(double width) =>
      rules.sizeClasses.lastWhere((c) => width >= c.minWidth, orElse: () => rules.sizeClasses.first);

  /// Width the content actually uses (capped on big screens, minus page padding).
  double contentWidth(double width) {
    final c = sizeClassFor(width);
    return math.min(width, rules.maxContentWidth) - 2 * c.pagePadding;
  }

  /// Product cards per row: the class's column count, reduced if cards would get narrower than min_width.
  int gridColumns(double width) {
    final c = sizeClassFor(width);
    final available = contentWidth(width);
    final fit = ((available + c.gutter) / (rules.productCard.minWidth + c.gutter)).floor();
    return math.max(1, math.min(c.gridColumns, fit));
  }

  bool usesRail(double width) => sizeClassFor(width).navigation == NavigationStyle.rail;

  bool productSideBySide(double width) => sizeClassFor(width).productLayout == ProductLayout.sideBySide;
}
