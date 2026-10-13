// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'layout_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LayoutSchema _$LayoutSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'LayoutSchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'size_classes',
            'max_content_width',
            'product_card',
            'list_card',
            'form_max_width',
            'side_by_side_video_fraction',
          ],
        );
        final val = LayoutSchema(
          sizeClasses: $checkedConvert(
            'size_classes',
            (v) => (v as List<dynamic>)
                .map((e) => SizeClassSchema.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
          maxContentWidth: $checkedConvert(
            'max_content_width',
            (v) => (v as num).toDouble(),
          ),
          productCard: $checkedConvert(
            'product_card',
            (v) => ProductCardSchema.fromJson(v as Map<String, dynamic>),
          ),
          listCard: $checkedConvert(
            'list_card',
            (v) => ListCardSchema.fromJson(v as Map<String, dynamic>),
          ),
          formMaxWidth: $checkedConvert(
            'form_max_width',
            (v) => (v as num).toDouble(),
          ),
          sideBySideVideoFraction: $checkedConvert(
            'side_by_side_video_fraction',
            (v) => (v as num).toDouble(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'sizeClasses': 'size_classes',
        'maxContentWidth': 'max_content_width',
        'productCard': 'product_card',
        'listCard': 'list_card',
        'formMaxWidth': 'form_max_width',
        'sideBySideVideoFraction': 'side_by_side_video_fraction',
      },
    );

SizeClassSchema _$SizeClassSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SizeClassSchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'name',
            'min_width',
            'grid_columns',
            'gutter',
            'page_padding',
            'navigation',
            'product_layout',
          ],
        );
        final val = SizeClassSchema(
          name: $checkedConvert('name', (v) => v as String),
          minWidth: $checkedConvert('min_width', (v) => (v as num).toDouble()),
          gridColumns: $checkedConvert(
            'grid_columns',
            (v) => (v as num).toInt(),
          ),
          gutter: $checkedConvert('gutter', (v) => (v as num).toDouble()),
          pagePadding: $checkedConvert(
            'page_padding',
            (v) => (v as num).toDouble(),
          ),
          navigation: $checkedConvert(
            'navigation',
            (v) => $enumDecode(_$NavigationStyleEnumMap, v),
          ),
          productLayout: $checkedConvert(
            'product_layout',
            (v) => $enumDecode(_$ProductLayoutEnumMap, v),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'minWidth': 'min_width',
        'gridColumns': 'grid_columns',
        'pagePadding': 'page_padding',
        'productLayout': 'product_layout',
      },
    );

const _$NavigationStyleEnumMap = {
  NavigationStyle.bottomBar: 'bottom_bar',
  NavigationStyle.rail: 'rail',
};

const _$ProductLayoutEnumMap = {
  ProductLayout.stacked: 'stacked',
  ProductLayout.sideBySide: 'side_by_side',
};

ProductCardSchema _$ProductCardSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ProductCardSchema', json, ($checkedConvert) {
  $checkKeys(json, allowedKeys: const ['aspect_ratio', 'min_width']);
  final val = ProductCardSchema(
    aspectRatio: $checkedConvert('aspect_ratio', (v) => (v as num).toDouble()),
    minWidth: $checkedConvert('min_width', (v) => (v as num).toDouble()),
  );
  return val;
}, fieldKeyMap: const {'aspectRatio': 'aspect_ratio', 'minWidth': 'min_width'});

ListCardSchema _$ListCardSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ListCardSchema',
      json,
      ($checkedConvert) {
        $checkKeys(json, allowedKeys: const ['min_width', 'max_columns']);
        final val = ListCardSchema(
          minWidth: $checkedConvert('min_width', (v) => (v as num).toDouble()),
          maxColumns: $checkedConvert('max_columns', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {'minWidth': 'min_width', 'maxColumns': 'max_columns'},
    );
