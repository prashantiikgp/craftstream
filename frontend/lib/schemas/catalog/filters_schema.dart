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
  final List<SortOptionSchema> sortOptions;

  const FiltersSchema({
    required this.search,
    required this.pageSize,
    required this.featuredTags,
    required this.maxChips,
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

@JsonEnum(fieldRename: FieldRename.snake)
enum SortId { newest, priceLow, priceHigh }

@JsonSerializable()
class SortOptionSchema {
  final SortId id;
  @JsonKey(name: 'default')
  final bool isDefault;

  const SortOptionSchema({required this.id, this.isDefault = false});

  factory SortOptionSchema.fromJson(Map<String, dynamic> json) => _$SortOptionSchemaFromJson(json);
}
