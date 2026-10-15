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
    for (final o in rules.sortOptions) {
      if ((o.field == null) != (o.direction == null)) {
        throw FiltersRulesError('sort option "${o.id}" needs both field and direction, or neither (API order)');
      }
    }
  }

  Duration get debounce => Duration(milliseconds: rules.search.debounceMs);

  int get pageSize => rules.pageSize;

  List<String> get sortIds => [for (final o in rules.sortOptions) o.id];

  String get defaultSort => rules.sortOptions.firstWhere((o) => o.isDefault).id;

  SortOptionSchema _option(String id) =>
      rules.sortOptions.firstWhere((o) => o.id == id, orElse: () => throw FiltersRulesError('unknown sort "$id"'));

  /// The strings.yml key a sort option shows.
  String sortLabel(String id) => _option(id).label;

  /// Every sort label key, for the startup cross-check.
  Iterable<String> get sortLabels => rules.sortOptions.map((o) => o.label);

  /// Every field a sort reads, so a check can hold them against the model.
  Set<String> get sortFields => {for (final o in rules.sortOptions) ?o.field};

  /// The sort with this id; throws [FiltersRulesError] for an id filters.yml does not list.
  String sortNamed(String id) => _option(id).id;

  /// The tag to show after the buyer taps [tapped] while [current] is selected (null = every tag).
  String? nextTag(String? current, String tapped) => rules.tagRetapClears && current == tapped ? null : tapped;

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

  /// Sorts loaded results on the device by the option's field and direction; an option without a field keeps
  /// the API's order. [fieldOf] reads a field by its model name (`price`). Equal values keep their order.
  List<T> sort<T>(List<T> items, String sortId, Object? Function(T item, String field) fieldOf) {
    final o = _option(sortId);
    final field = o.field;
    if (field == null) return [...items];
    final keyed = [for (final (i, item) in items.indexed) (i, fieldOf(item, field), item)];
    final sign = o.direction == SortDirection.desc ? -1 : 1;
    keyed.sort((a, b) {
      final c = _compare(a.$2, b.$2) * sign;
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final k in keyed) k.$3];
  }

  /// Nulls first; values that are not Comparable compare as text.
  static int _compare(Object? a, Object? b) {
    if (a == null || b == null) return a == null ? (b == null ? 0 : -1) : 1;
    if (a is Comparable && b is Comparable) return a.compareTo(b);
    return '$a'.compareTo('$b');
  }
}
