/// Discover state: the search text, the selected tag and the sort, and the results loaded so far (one
/// page of `page_size` at a time, "Load more" fetches the next). Searching rules (debounce, minimum
/// length, page size, chips, sorting) come from filters.yml through FiltersEngine.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../data/generated/models.dart';
import '../../data/providers.dart';

class DiscoverQuery {
  final String text;
  final String? tag;

  /// A sort option id from filters.yml.
  final String sort;
  const DiscoverQuery({this.text = '', this.tag, required this.sort});

  DiscoverQuery copyWith({String? text, String? Function()? tag, String? sort}) =>
      DiscoverQuery(text: text ?? this.text, tag: tag == null ? this.tag : tag(), sort: sort ?? this.sort);
}

class DiscoverController extends Notifier<DiscoverQuery> {
  @override
  DiscoverQuery build() => DiscoverQuery(sort: ref.read(appConfigProvider).filters.defaultSort);

  void setText(String text) {
    if (text != state.text) state = state.copyWith(text: text);
  }

  /// Selecting the selected tag again clears it (filters.yml `tag_retap_clears`).
  void toggleTag(String tag) =>
      state = state.copyWith(tag: () => ref.read(appConfigProvider).filters.nextTag(state.tag, tag));

  void clearTag() => state = state.copyWith(tag: () => null);

  void showTag(String tag) => state = DiscoverQuery(tag: tag, sort: state.sort);

  void setSort(String sort) => state = state.copyWith(sort: sort);

  void clear() => state = DiscoverQuery(sort: state.sort);
}

final discoverControllerProvider = NotifierProvider<DiscoverController, DiscoverQuery>(DiscoverController.new);

/// Results loaded so far for the current text + tag.
class DiscoverFeed {
  final List<ProductSummary> items;

  /// The API's cursor for the next page; null when everything is loaded.
  final String? nextCursor;
  final bool loadingMore;

  /// The last "Load more" failed; the loaded items stay and the button offers a retry.
  final bool moreFailed;

  const DiscoverFeed({required this.items, this.nextCursor, this.loadingMore = false, this.moreFailed = false});

  bool get hasMore => nextCursor != null;
}

/// The first page for the current text + tag; `loadMore` appends the next one. A new search (text or tag)
/// starts again from the first page; sorting does not refetch.
class DiscoverFeedController extends AsyncNotifier<DiscoverFeed> {
  ({String? q, String? tag}) _query = (q: null, tag: null);

  /// Bumped by every new search, so a "Load more" that was in flight for an older one is dropped.
  int _search = 0;

  @override
  Future<DiscoverFeed> build() async {
    _search++;
    final filters = ref.watch(appConfigProvider).filters;
    final (text, tag) = ref.watch(discoverControllerProvider.select((q) => (q.text, q.tag)));
    _query = (q: filters.normaliseQuery(text), tag: tag);
    final page = await _fetch(null);
    return DiscoverFeed(items: page.items, nextCursor: page.nextCursor);
  }

  Future<ProductPage> _fetch(String? cursor) => ref
      .read(catalogRepositoryProvider)
      .search(q: _query.q, tag: _query.tag, cursor: cursor, limit: ref.read(appConfigProvider).filters.pageSize);

  Future<void> loadMore() async {
    final feed = state.value;
    if (feed == null || !feed.hasMore || feed.loadingMore || state.isLoading) return;
    final search = _search;
    state = AsyncData(DiscoverFeed(items: feed.items, nextCursor: feed.nextCursor, loadingMore: true));
    DiscoverFeed next;
    try {
      final page = await _fetch(feed.nextCursor);
      next = DiscoverFeed(items: [...feed.items, ...page.items], nextCursor: page.nextCursor);
    } catch (_) {
      next = DiscoverFeed(items: feed.items, nextCursor: feed.nextCursor, moreFailed: true);
    }
    // A new search started meanwhile: its first page wins. (While it loads, state still holds this
    // feed as its previous value, so comparing values is not enough.)
    if (ref.mounted && search == _search && !state.isLoading) state = AsyncData(next);
  }
}

final discoverFeedProvider = AsyncNotifierProvider<DiscoverFeedController, DiscoverFeed>(DiscoverFeedController.new);

/// Loaded results in the chosen order.
final discoverResultsProvider = Provider<AsyncValue<List<ProductSummary>>>((ref) {
  final filters = ref.watch(appConfigProvider).filters;
  final sort = ref.watch(discoverControllerProvider.select((q) => q.sort));
  return ref
      .watch(discoverFeedProvider)
      .whenData((feed) => filters.sort(feed.items, sort, (p, field) => p.toJson()[field]));
});

/// Chips: featured tags first, then the most used. Empty (chips hidden) if tags fail to load.
final discoverChipsProvider = FutureProvider<List<String>>((ref) async {
  final filters = ref.watch(appConfigProvider).filters;
  try {
    return filters.chipTags(await ref.watch(catalogRepositoryProvider).tags());
  } catch (_) {
    return const [];
  }
});
