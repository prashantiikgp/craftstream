/// Shape of assets/config/catalog/filters.yml: search timing, page size, tag chips and sort options.
library;

import 'package:json_annotation/json_annotation.dart';

part 'filters_schema.g.dart';

@JsonSerializable()
class FiltersSchema {
  final SearchSchema search;
  final int pageSize;
  final List<String> featuredTags;
  final int maxChips;
  final bool tagRetapClears;
  final List<SortOptionSchema> sortOptions;

  const FiltersSchema({
    required this.search,
    required this.pageSize,
    required this.featuredTags,
    required this.maxChips,
    required this.tagRetapClears,
    required this.sortOptions,
  });

  factory FiltersSchema.fromJson(Map<String, dynamic> json) => _$FiltersSchemaFromJson(json);
}

@JsonSerializable()
class SearchSchema {
  final int debounceMs;
  final int minQueryLength;
  final int maxQueryLength;

  const SearchSchema({required this.debounceMs, required this.minQueryLength, required this.maxQueryLength});

  factory SearchSchema.fromJson(Map<String, dynamic> json) => _$SearchSchemaFromJson(json);
}

@JsonEnum()
enum SortDirection { asc, desc }

@JsonSerializable()
class SortOptionSchema {
  final String id;

  /// A strings.yml key.
  final String label;
  @JsonKey(name: 'default')
  final bool isDefault;

  /// The ProductSummary field to sort by; null keeps the API's order.
  final String? field;
  final SortDirection? direction;

  const SortOptionSchema({required this.id, required this.label, this.isDefault = false, this.field, this.direction});

  factory SortOptionSchema.fromJson(Map<String, dynamic> json) => _$SortOptionSchemaFromJson(json);
}
