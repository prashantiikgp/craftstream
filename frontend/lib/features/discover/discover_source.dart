/// Data for ui/screens/discover.yml. Wraps the discover controllers (search text, tag, sort, paged results) as
/// the values the screen binds to, and the calls its bricks make. Product fields are ProductSummary's
/// (models/product_summary.yml).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../shared/screens/screen_scope.dart';
import 'discover_controller.dart';

const discoverCalls = {'set_text', 'toggle_tag', 'set_sort', 'load_more', 'retry', 'clear'};

ScreenData discoverSource(WidgetRef ref, Map<String, String> params) {
  final filters = ref.watch(appConfigProvider).filters;
  final query = ref.watch(discoverControllerProvider);
  final results = ref.watch(discoverResultsProvider);
  final feed = ref.watch(discoverFeedProvider).value;
  final chips = ref.watch(discoverChipsProvider).value ?? const <String>[];
  // Same test the search uses: text shorter than the minimum shows everything.
  final filtered = query.tag != null || filters.normaliseQuery(query.text) != null;
  final items = switch (results) {
    AsyncData(:final value) => value,
    _ => null,
  };
  final failed = results is AsyncError;
  final controller = ref.read(discoverControllerProvider.notifier);

  return ScreenData.ready(
    {
      'discover': {
        'text': query.text,
        'debounce_ms': filters.debounce.inMilliseconds,
        'all_selected': query.tag == null,
        'chips': [
          for (final t in chips) {'value': t, 'selected': query.tag == t},
        ],
        'sorts': [
          for (final id in filters.sortIds) {'value': id, 'label': filters.sortLabel(id), 'selected': id == query.sort},
        ],
        'tag': query.tag,
        'loading': items == null && !failed,
        'count': items?.length ?? 0,
        'has_more': feed?.hasMore ?? false,
        'items': items?.map((p) => p.toJson()).toList(),
        'show_grid': (items == null && !failed) || (items?.isNotEmpty ?? false),
        'none': items != null && items.isEmpty && !filtered,
        'no_match': items != null && items.isEmpty && filtered,
        'failed': failed,
        'more': {
          'show': items != null && feed != null && (feed.hasMore || feed.moreFailed),
          'loading': feed?.loadingMore ?? false,
          'failed': feed?.moreFailed ?? false,
        },
      },
    },
    {
      'set_text': (v) => controller.setText('${v ?? ''}'),
      // The "All" chip passes null: clear the tag.
      'toggle_tag': (v) => v == null ? controller.clearTag() : controller.toggleTag('$v'),
      'set_sort': (v) => controller.setSort(filters.sortNamed('$v')),
      'load_more': (_) => ref.read(discoverFeedProvider.notifier).loadMore(),
      'retry': (_) => ref.invalidate(discoverFeedProvider),
      'clear': (_) => controller.clear(),
    },
  );
}
