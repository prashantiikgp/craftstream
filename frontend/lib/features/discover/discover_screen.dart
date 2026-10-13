/// Buyer home: search by keyword, filter by tag, browse ready products. Posters only, no autoplay.
/// Results come one small page at a time; the buyer asks for more (no auto-loading on slow networks).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../data/generated/models.dart';
import '../../shared/widgets/ds.dart';
import 'discover_controller.dart';
import 'widgets/filter_bar.dart';
import 'widgets/product_card.dart';
import 'widgets/search_field.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final layout = ref.watch(appConfigProvider).layout;
    final results = ref.watch(discoverResultsProvider);
    final query = ref.watch(discoverControllerProvider);
    // Same test the search uses: text shorter than the minimum shows everything.
    final filtered = query.tag != null || ref.watch(appConfigProvider).filters.normaliseQuery(query.text) != null;
    final feed = ref.watch(discoverFeedProvider).value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final sc = layout.sizeClassFor(width);
        final inset = layout.horizontalInset(width);
        final columns = layout.gridColumns(width);
        final aspect = layout.rules.productCard.aspectRatio;
        final cardWidth = (width - 2 * inset - sc.gutter * (columns - 1)) / columns;
        final rowHeight = cardWidth / aspect + ProductCard.infoHeight(context) + 2;

        SliverGridDelegate grid() => SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: sc.gutter,
          crossAxisSpacing: sc.gutter,
          mainAxisExtent: rowHeight,
        );

        Widget padded(Widget sliver) => SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          sliver: sliver,
        );
        Widget box(Widget child) => padded(SliverToBoxAdapter(child: child));

        final body = switch (results) {
          // Nothing live at all: no search to blame, so nothing to clear.
          AsyncData(:final value) when value.isEmpty && !filtered => box(
            EmptyState(
              icon: Icons.storefront_outlined,
              title: context.s('discover.none_title'),
              message: context.s('discover.none_message'),
            ),
          ),
          AsyncData(:final value) when value.isEmpty => box(
            EmptyState(
              icon: Icons.search_off,
              title: context.s('discover.empty_title'),
              message: context.s('discover.empty_message'),
              action: AppButton(
                context.s('discover.clear_filters'),
                onPressed: ref.read(discoverControllerProvider.notifier).clear,
                variant: ButtonVariant.secondary,
              ),
            ),
          ),
          AsyncData(:final value) => padded(
            SliverGrid.builder(
              gridDelegate: grid(),
              itemCount: value.length,
              itemBuilder: (context, i) => ProductCard(
                product: value[i],
                posterAspectRatio: aspect,
                onTap: () => context.push('/product/${value[i].id}'),
              ),
            ),
          ),
          AsyncError() => box(LoadError(onRetry: () => ref.invalidate(discoverFeedProvider))),
          _ => padded(
            SliverGrid.builder(
              gridDelegate: grid(),
              itemCount: columns * 2,
              itemBuilder: (_, _) => ProductCardSkeleton(posterAspectRatio: aspect),
            ),
          ),
        };

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: sc.pagePadding)),
            box(_Header(compact: !layout.usesRail(width))),
            box(SizedBox(height: t.space.lg)),
            box(const SearchField()),
            box(SizedBox(height: t.space.md)),
            box(const FilterBar()),
            box(SizedBox(height: t.space.md)),
            box(_ResultLine(results: results, query: query, more: feed?.hasMore ?? false)),
            box(SizedBox(height: t.space.md)),
            body,
            if (results is AsyncData && feed != null && (feed.hasMore || feed.moreFailed)) ...[
              box(SizedBox(height: t.space.xl)),
              box(_LoadMore(feed: feed, onPressed: ref.read(discoverFeedProvider.notifier).loadMore)),
            ],
            SliverToBoxAdapter(child: SizedBox(height: sc.pagePadding * 2)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final bool compact;
  const _Header({required this.compact});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.s('discover.title'), style: compact ? context.type.h2 : context.type.h1),
        SizedBox(height: t.space.xs),
        Text(context.s('discover.subtitle'), style: context.type.body.copyWith(color: t.sub)),
      ],
    );
  }
}

class _ResultLine extends StatelessWidget {
  final AsyncValue<List<ProductSummary>> results;
  final DiscoverQuery query;
  final bool more;
  const _ResultLine({required this.results, required this.query, required this.more});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = results.value;
    final text = switch (items) {
      null => context.s('discover.searching'),
      final list when list.length == 1 => context.s('discover.count_one'),
      final list when more => context.s('discover.count_more', {'count': list.length}),
      final list => context.s('discover.count_many', {'count': list.length}),
    };
    return Wrap(
      spacing: t.space.sm,
      runSpacing: t.space.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: context.type.caption.copyWith(color: t.sub)),
        if (query.tag != null) StatusBadge(context.s('discover.tag_filter', {'tag': query.tag!}), tone: Tone.brand),
      ],
    );
  }
}

/// "Show more": the next page on request. Keeps the loaded results when it fails.
class _LoadMore extends StatelessWidget {
  final DiscoverFeed feed;
  final VoidCallback onPressed;
  const _LoadMore({required this.feed, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        if (feed.moreFailed) ...[
          Text(
            context.s('discover.load_more_failed'),
            textAlign: TextAlign.center,
            style: context.type.caption.copyWith(color: t.danger.ink),
          ),
          SizedBox(height: t.space.sm),
        ],
        AppButton(
          feed.moreFailed ? context.s('common.retry') : context.s('discover.load_more'),
          onPressed: feed.loadingMore ? null : onPressed,
          loading: feed.loadingMore,
          variant: ButtonVariant.secondary,
          icon: feed.moreFailed ? Icons.refresh : Icons.expand_more,
        ),
      ],
    );
  }
}
