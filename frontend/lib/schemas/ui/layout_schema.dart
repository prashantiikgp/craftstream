/// Shape of assets/config/ui/layout.yml: size classes, grid and product-screen layout.
library;

import 'package:json_annotation/json_annotation.dart';

part 'layout_schema.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum NavigationStyle { bottomBar, rail }

@JsonEnum(fieldRename: FieldRename.snake)
enum ProductLayout { stacked, sideBySide }

@JsonSerializable()
class LayoutSchema {
  final List<SizeClassSchema> sizeClasses;
  final double maxContentWidth;
  final ProductCardSchema productCard;
  final double sideBySideVideoFraction;

  const LayoutSchema({
    required this.sizeClasses,
    required this.maxContentWidth,
    required this.productCard,
    required this.sideBySideVideoFraction,
  });

  factory LayoutSchema.fromJson(Map<String, dynamic> json) => _$LayoutSchemaFromJson(json);
}

@JsonSerializable()
class SizeClassSchema {
  final String name;
  final double minWidth;
  final int gridColumns;
  final double gutter;
  final double pagePadding;
  final NavigationStyle navigation;
  final ProductLayout productLayout;

  const SizeClassSchema({
    required this.name,
    required this.minWidth,
    required this.gridColumns,
    required this.gutter,
    required this.pagePadding,
    required this.navigation,
    required this.productLayout,
  });

  factory SizeClassSchema.fromJson(Map<String, dynamic> json) => _$SizeClassSchemaFromJson(json);
}

@JsonSerializable()
class ProductCardSchema {
  final double aspectRatio;
  final double minWidth;

  const ProductCardSchema({required this.aspectRatio, required this.minWidth});

  factory ProductCardSchema.fromJson(Map<String, dynamic> json) => _$ProductCardSchemaFromJson(json);
}
