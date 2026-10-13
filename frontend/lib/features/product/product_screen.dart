/// Product page: the low-bandwidth process video, details and Buy. Video beside the details on
/// wide screens, above them on phones and portrait tablets (layout.yml).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../data/generated/models.dart';
import '../../shared/widgets/ds.dart';
import '../discover/discover_controller.dart';
import 'product_controller.dart';
import 'widgets/product_details.dart';
import 'widgets/process_video.dart';

class ProductScreen extends ConsumerWidget {
  final String productId;
  const ProductScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));
    final layout = ref.watch(appConfigProvider).layout;

    void back() => context.canPop() ? context.pop() : context.go('/discover');
    void showTag(String tag) {
      ref.read(discoverControllerProvider.notifier).showTag(tag);
      context.go('/discover');
    }

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final sideBySide = layout.productSideBySide(width);
      final p = product.value;
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: context.s('common.back'), icon: const Icon(Icons.arrow_back), onPressed: back),
          title: Text(context.s('product.screen_title')),
        ),
        bottomNavigationBar: p != null && !sideBySide ? _BuyBar(product: p) : null,
        body: switch (product) {
          AsyncData(:final value) => sideBySide
              ? _Wide(product: value, fraction: layout.rules.sideBySideVideoFraction, onTag: showTag)
              : PageScroll(children: [
                  ProcessVideo(product: value),
                  SizedBox(height: context.tokens.space.xl),
                  ProductDetails(product: value, onTag: showTag),
                ]),
          AsyncError() => PageScroll(children: [
              LoadError(
                message: context.s('product.load_error'),
                onRetry: () => ref.invalidate(productProvider(productId)),
              ),
            ]),
          _ => const _Loading(),
        },
      );
    });
  }
}

class _Wide extends ConsumerWidget {
  final Product product;
  final double fraction;
  final ValueChanged<String> onTag;
  const _Wide({required this.product, required this.fraction, required this.onTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(appConfigProvider).layout;
    final t = context.tokens;
    return LayoutBuilder(builder: (context, constraints) {
      final inset = layout.horizontalInset(constraints.maxWidth);
      final pad = layout.sizeClassFor(constraints.maxWidth).pagePadding;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(inset, pad, inset, pad * 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: (fraction * 100).round(), child: ProcessVideo(product: product)),
          SizedBox(width: t.space.xxl),
          Expanded(
            flex: ((1 - fraction) * 100).round(),
            child: ProductDetails(product: product, onTag: onTag, buy: _BuyButton(product: product)),
          ),
        ]),
      );
    });
  }
}

class _BuyButton extends StatelessWidget {
  final Product product;
  const _BuyButton({required this.product});

  @override
  Widget build(BuildContext context) => AppButton(
        context.s('product.buy'),
        icon: Icons.shopping_bag_outlined,
        size: ButtonSize.lg,
        expand: true,
        onPressed: product.videoStatus == 'ready' ? () => context.push('/product/${product.id}/buy') : null,
      );
}

/// Phones: price + Buy pinned to the bottom so it is always one tap away.
class _BuyBar extends StatelessWidget {
  final Product product;
  const _BuyBar({required this.product});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.hair))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space.lg, vertical: t.space.md),
          child: Row(children: [
            Expanded(child: PriceText(product.price, currency: product.currency)),
            SizedBox(width: t.space.md),
            SizedBox(width: 180, child: _BuyButton(product: product)),
          ]),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PageScroll(children: [
      AspectRatio(aspectRatio: 16 / 9, child: Skeleton(height: double.infinity, radius: t.radius.md)),
      SizedBox(height: t.space.xl),
      const Skeleton(width: 260, height: 28),
      SizedBox(height: t.space.sm),
      const Skeleton(width: 140, height: 16),
      SizedBox(height: t.space.lg),
      const Skeleton(width: 90, height: 24),
      SizedBox(height: t.space.xl),
      const Skeleton(height: 14),
      SizedBox(height: t.space.sm),
      const Skeleton(height: 14),
    ]);
  }
}
