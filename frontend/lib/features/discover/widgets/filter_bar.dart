import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../schemas/catalog/filters_schema.dart';
import '../../../shared/widgets/ds.dart';
import '../discover_controller.dart';

/// Tag chips (scroll sideways on phones) and the sort menu.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  static String sortLabel(BuildContext context, SortId id) => switch (id) {
    SortId.newest => context.s('discover.sort_newest'),
    SortId.priceLow => context.s('discover.sort_price_low'),
    SortId.priceHigh => context.s('discover.sort_price_high'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final query = ref.watch(discoverControllerProvider);
    final controller = ref.read(discoverControllerProvider.notifier);
    final chips = ref.watch(discoverChipsProvider).value ?? const <String>[];
    final sorts = ref.watch(appConfigProvider).filters.sortIds;

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TagChip(
                  context.s('discover.all_tags'),
                  selected: query.tag == null,
                  onSelected: (_) {
                    if (query.tag != null) controller.toggleTag(query.tag!);
                  },
                ),
                for (final tag in chips) ...[
                  SizedBox(width: t.space.sm),
                  TagChip(tag, selected: query.tag == tag, onSelected: (_) => controller.toggleTag(tag)),
                ],
              ],
            ),
          ),
        ),
        SizedBox(width: t.space.sm),
        PopupMenuButton<SortId>(
          tooltip: context.s('discover.sort_label'),
          initialValue: query.sort,
          onSelected: controller.setSort,
          itemBuilder: (context) => [
            for (final id in sorts) PopupMenuItem(value: id, child: Text(sortLabel(context, id))),
          ],
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.sm, vertical: t.space.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_vert, size: 18, color: t.sub),
                SizedBox(width: t.space.xs),
                Text(sortLabel(context, query.sort), style: context.type.label.copyWith(color: t.sub)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
