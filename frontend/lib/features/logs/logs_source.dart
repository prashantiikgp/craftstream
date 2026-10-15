/// Data for ui/screens/logs.yml: the activity log, newest first, for every listing or one (route
/// /logs/listing/:product_id). Entry fields are LogEntry's (models/log_entry.yml) plus `tone` (the level's
/// tone from logs/activity_log.yml) and `date` / `time` for the row.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../data/generated/models.dart';
import '../../shared/screens/screen_scope.dart';
import 'logs_controller.dart';

const logsCalls = {'set_group', 'set_level', 'load_more', 'refresh', 'retry'};

ScreenData logsSource(WidgetRef ref, Map<String, String> params) {
  final config = ref.watch(appConfigProvider);
  final rules = config.activityLog;
  final productId = params['product_id'];
  final filter = ref.watch(logsFilterProvider);
  final feed = ref.watch(logsFeedProvider(productId));
  final filters = ref.read(logsFilterProvider.notifier);
  final controller = ref.read(logsFeedProvider(productId).notifier);
  final items = feed.value?.items;
  final failed = feed is AsyncError && items == null;

  Map<String, Object?> row(LogEntry e) {
    final at = e.at.toLocal();
    return {
      ...e.toJson(),
      'tone': rules.toneOf(e.level),
      'level_label': _label(config, rules.levelLabel(e.level), e.level),
      'date': config.format.date(at),
      'time': config.format.time(at),
    };
  }

  final calls = <String, Object? Function(Object?)>{
    'set_group': (v) => filters.setGroup(v as String?),
    'set_level': (v) => filters.setLevel(v as String?),
    'load_more': (_) => controller.loadMore(),
    'refresh': (_) => controller.refresh(),
    'retry': (_) => ref.invalidate(logsFeedProvider(productId)),
  };
  if (failed) return ScreenData(SourceState.error, const {}, calls);
  if (items == null) return const ScreenData(SourceState.loading);

  return ScreenData.ready({
    'logs': {
      'product_id': productId,
      'groups': [
        for (final g in rules.groups)
          {'value': g, 'label': _label(config, rules.groupLabel(g), g), 'selected': filter.group == g},
      ],
      'all_groups': filter.group == null,
      'levels': [
        for (final l in rules.levels)
          {'value': l, 'label': _label(config, rules.levelLabel(l), l), 'selected': filter.level == l},
      ],
      'all_levels': filter.level == null,
      'count': items.length,
      'has_more': feed.value?.hasMore ?? false,
      'refreshing': feed.value?.refreshing ?? false,
      'items': items.map(row).toList(),
      'none': items.isEmpty,
      'more': {
        'show': feed.value!.hasMore || feed.value!.moreFailed,
        'loading': feed.value?.loadingMore ?? false,
        'failed': feed.value?.moreFailed ?? false,
      },
    },
  }, calls);
}

/// A strings.yml key's text; a value activity_log.yml does not name (a level the server added) shows as is.
String _label(AppConfig config, String? key, String value) => key == null ? value : config.strings.get(key);
