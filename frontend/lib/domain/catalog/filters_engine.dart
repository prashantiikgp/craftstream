/// Search and filter rules from filters.yml. Pure Dart: the Discover controller asks it what to send.
library;

import '../../schemas/catalog/filters_schema.dart';

class FiltersRulesError implements Exception {
  final String message;
  const FiltersRulesError(this.message);
  @override
  String toString() => 'filters.yml: $message';
}

class FiltersEngine {
  final FiltersSchema rules;

  FiltersEngine(this.rules) {
    final s = rules.search;
    if (s.debounceMs < 0 || s.debounceMs > 2000) throw const FiltersRulesError('search.debounce_ms must be 0-2000');
    if (s.minQueryLength < 1) throw const FiltersRulesError('search.min_query_length must be at least 1');
    if (s.maxQueryLength < s.minQueryLength) {
      throw const FiltersRulesError('search.max_query_length must be >= min_query_length');
    }
    if (rules.pageSize < 1 || rules.pageSize > 100) throw const FiltersRulesError('page_size must be 1-100');
    if (rules.maxChips < 1) throw const FiltersRulesError('max_chips must be at least 1');
    if (rules.sortOptions.isEmpty) throw const FiltersRulesError('sort_options must not be empty');
    if (rules.sortOptions.where((o) => o.isDefault).length != 1) {
      throw const FiltersRulesError('exactly one sort option must be default: true');
    }
    if (rules.sortOptions.map((o) => o.id).toSet().length != rules.sortOptions.length) {
      throw const FiltersRulesError('sort option ids must be unique');
    }
  }

  Duration get debounce => Duration(milliseconds: rules.search.debounceMs);

  int get pageSize => rules.pageSize;

  List<SortId> get sortIds => [for (final o in rules.sortOptions) o.id];

  SortId get defaultSort => rules.sortOptions.firstWhere((o) => o.isDefault).id;

  /// What to send as `q`: trimmed, single-spaced, capped; null when too short to search on.
  String? normaliseQuery(String raw) {
    var q = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.length < rules.search.minQueryLength) return null;
    if (q.length > rules.search.maxQueryLength) q = q.substring(0, rules.search.maxQueryLength).trimRight();
    return q;
  }

  /// Chips to show: featured tags that exist on the server first, then the server's most used, de-duplicated.
  List<String> chipTags(List<String> serverTags) {
    final available = serverTags.toSet();
    final out = <String>[
      for (final t in rules.featuredTags)
        if (available.contains(t)) t,
    ];
    for (final t in serverTags) {
      if (out.length >= rules.maxChips) break;
      if (!out.contains(t)) out.add(t);
    }
    return out.take(rules.maxChips).toList();
  }

  /// Sorts loaded results on the device. `newest` keeps the API's order.
  List<T> sort<T>(List<T> items, SortId sort, num Function(T) priceOf) {
    final out = [...items];
    switch (sort) {
      case SortId.newest:
        break;
      case SortId.priceLow:
        out.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
      case SortId.priceHigh:
        out.sort((a, b) => priceOf(b).compareTo(priceOf(a)));
    }
    return out;
  }
}
