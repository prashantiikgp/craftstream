// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filters_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FiltersSchema _$FiltersSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'FiltersSchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'search',
            'page_size',
            'featured_tags',
            'max_chips',
            'tag_retap_clears',
            'sort_options',
          ],
        );
        final val = FiltersSchema(
          search: $checkedConvert(
            'search',
            (v) => SearchSchema.fromJson(v as Map<String, dynamic>),
          ),
          pageSize: $checkedConvert('page_size', (v) => (v as num).toInt()),
          featuredTags: $checkedConvert(
            'featured_tags',
            (v) => (v as List<dynamic>).map((e) => e as String).toList(),
          ),
          maxChips: $checkedConvert('max_chips', (v) => (v as num).toInt()),
          tagRetapClears: $checkedConvert('tag_retap_clears', (v) => v as bool),
          sortOptions: $checkedConvert(
            'sort_options',
            (v) => (v as List<dynamic>)
                .map(
                  (e) => SortOptionSchema.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'pageSize': 'page_size',
        'featuredTags': 'featured_tags',
        'maxChips': 'max_chips',
        'tagRetapClears': 'tag_retap_clears',
        'sortOptions': 'sort_options',
      },
    );

SearchSchema _$SearchSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SearchSchema',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'debounce_ms',
            'min_query_length',
            'max_query_length',
          ],
        );
        final val = SearchSchema(
          debounceMs: $checkedConvert('debounce_ms', (v) => (v as num).toInt()),
          minQueryLength: $checkedConvert(
            'min_query_length',
            (v) => (v as num).toInt(),
          ),
          maxQueryLength: $checkedConvert(
            'max_query_length',
            (v) => (v as num).toInt(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'debounceMs': 'debounce_ms',
        'minQueryLength': 'min_query_length',
        'maxQueryLength': 'max_query_length',
      },
    );

SortOptionSchema _$SortOptionSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SortOptionSchema', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['id', 'label', 'default', 'field', 'direction'],
      );
      final val = SortOptionSchema(
        id: $checkedConvert('id', (v) => v as String),
        label: $checkedConvert('label', (v) => v as String),
        isDefault: $checkedConvert('default', (v) => v as bool? ?? false),
        field: $checkedConvert('field', (v) => v as String?),
        direction: $checkedConvert(
          'direction',
          (v) => $enumDecodeNullable(_$SortDirectionEnumMap, v),
        ),
      );
      return val;
    }, fieldKeyMap: const {'isDefault': 'default'});

const _$SortDirectionEnumMap = {
  SortDirection.asc: 'asc',
  SortDirection.desc: 'desc',
};
