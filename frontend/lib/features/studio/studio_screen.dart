/// Artisan home: their listings and each video's status (live, processing, failed).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../data/generated/models.dart';
import '../../shared/widgets/ds.dart';
import 'studio_controller.dart';
import 'widgets/listing_card.dart';

class StudioScreen extends ConsumerWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final products = ref.watch(myProductsProvider);
    final layout = ref.watch(appConfigProvider).layout;

    return LayoutBuilder(builder: (context, constraints) {
      final columns = layout.listColumns(constraints.maxWidth);
      final gutter = layout.sizeClassFor(constraints.maxWidth).gutter;
      return PageScroll(children: [
        SectionHeader(
          context.s('studio.title'),
          subtitle: context.s('studio.subtitle'),
          action: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: context.s('studio.refresh'),
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(myProductsProvider),
            ),
            if (columns > 1)
              AppButton(context.s('studio.new_product'),
                  icon: Icons.add, onPressed: () => context.go('/studio/new')),
          ]),
        ),
        SizedBox(height: t.space.md),
        switch (products) {
          AsyncData(:final value) when value.isEmpty => EmptyState(
              icon: Icons.video_call_outlined,
              title: context.s('studio.empty_title'),
              message: context.s('studio.empty_message'),
              action: AppButton(context.s('studio.new_product'), onPressed: () => context.go('/studio/new')),
            ),
          AsyncData(:final value) => _Grid(columns: columns, gutter: gutter, products: value),
          AsyncError() => LoadError(onRetry: () => ref.invalidate(myProductsProvider)),
          _ => _Grid.loading(columns: columns, gutter: gutter),
        },
      ]);
    });
  }
}

class _Grid extends StatelessWidget {
  final int columns;
  final double gutter;
  final List<Product>? products;
  const _Grid({required this.columns, required this.gutter, required this.products});
  const _Grid.loading({required this.columns, required this.gutter}) : products = null;

  @override
  Widget build(BuildContext context) {
    final items = products;
    final children = items == null
        ? [for (var i = 0; i < 3; i++) const Skeleton(height: 120)]
        : [
            for (final p in items)
              ListingCard(
                product: p,
                onOpen: p.videoStatus == 'ready' ? () => context.push('/product/${p.id}') : null,
                onRetry: () => context.go('/studio/new'),
              ),
          ];
    return LayoutBuilder(builder: (context, constraints) {
      final w = (constraints.maxWidth - gutter * (columns - 1)) / columns;
      return Wrap(spacing: gutter, runSpacing: gutter, children: [
        for (final c in children) SizedBox(width: w, child: c),
      ]);
    });
  }
}
