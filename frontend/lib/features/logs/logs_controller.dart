/// The Activity log screen's state: the group and level filters, and the entries loaded so far for one listing
/// or for all (newest first, a page at a time). While the screen is open the newest page is re-read every
/// `refresh_seconds` (logs/activity_log.yml); leaving the screen stops it, so nothing polls in the background.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../data/generated/models.dart';
import '../../data/providers.dart';

class LogsFilter {
  final String? group;
  final String? level;
  const LogsFilter({this.group, this.level});
}

class LogsFilterController extends Notifier<LogsFilter> {
  @override
  LogsFilter build() => const LogsFilter();

  /// Choosing the chosen one again (or All, null) clears it.
  void setGroup(String? group) => state = LogsFilter(group: group == state.group ? null : group, level: state.level);
  void setLevel(String? level) => state = LogsFilter(group: state.group, level: level == state.level ? null : level);
}

final logsFilterProvider = NotifierProvider.autoDispose<LogsFilterController, LogsFilter>(LogsFilterController.new);

class LogsFeed {
  final List<LogEntry> items;
  final String? nextCursor;
  final bool loadingMore;
  final bool moreFailed;
  final bool refreshing;
  const LogsFeed({
    required this.items,
    this.nextCursor,
    this.loadingMore = false,
    this.moreFailed = false,
    this.refreshing = false,
  });
  bool get hasMore => nextCursor != null;

  LogsFeed copyWith({bool? loadingMore, bool? moreFailed, bool? refreshing}) => LogsFeed(
    items: items,
    nextCursor: nextCursor,
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailed: moreFailed ?? this.moreFailed,
    refreshing: refreshing ?? this.refreshing,
  );
}

/// Entries for one listing (the family argument) or for all (null).
class LogsFeedController extends AsyncNotifier<LogsFeed> {
  final String? productId;
  LogsFeedController(this.productId);

  Timer? _timer;

  @override
  Future<LogsFeed> build() async {
    final filter = ref.watch(logsFilterProvider);
    final every = ref.read(appConfigProvider).activityLog.refresh;
    _timer?.cancel();
    if (every != null) _timer = Timer.periodic(every, (_) => refresh());
    ref.onDispose(() => _timer?.cancel());
    final page = await _fetch(filter, null);
    return LogsFeed(items: page.items, nextCursor: page.nextCursor);
  }

  Future<LogPage> _fetch(LogsFilter f, String? cursor) => ref
      .read(logRepositoryProvider)
      .page(
        group: f.group,
        level: f.level,
        productId: productId,
        cursor: cursor,
        limit: ref.read(appConfigProvider).activityLog.pageSize,
      );

  Future<void> loadMore() async {
    final feed = state.value;
    if (feed == null || !feed.hasMore || feed.loadingMore || state.isLoading) return;
    state = AsyncData(feed.copyWith(loadingMore: true, moreFailed: false));
    try {
      final page = await _fetch(ref.read(logsFilterProvider), feed.nextCursor);
      if (!ref.mounted) return;
      state = AsyncData(LogsFeed(items: [...feed.items, ...page.items], nextCursor: page.nextCursor));
    } catch (_) {
      if (ref.mounted) state = AsyncData(feed.copyWith(moreFailed: true));
    }
  }

  /// Re-reads the newest page and puts it on top of what is loaded (no spinner; a failed refresh changes nothing).
  Future<void> refresh() async {
    final feed = state.value;
    if (feed == null || feed.refreshing || state.isLoading) return;
    state = AsyncData(feed.copyWith(refreshing: true));
    try {
      final page = await _fetch(ref.read(logsFilterProvider), null);
      if (!ref.mounted) return;
      final fresh = {for (final e in page.items) e.id};
      final current = state.value ?? feed;
      state = AsyncData(
        LogsFeed(
          items: [...page.items, ...current.items.where((e) => !fresh.contains(e.id))],
          nextCursor: current.items.length > page.items.length ? current.nextCursor : page.nextCursor,
        ),
      );
    } catch (_) {
      if (ref.mounted) state = AsyncData((state.value ?? feed).copyWith(refreshing: false));
    }
  }
}

final logsFeedProvider = AsyncNotifierProvider.autoDispose.family<LogsFeedController, LogsFeed, String?>(
  LogsFeedController.new,
);
