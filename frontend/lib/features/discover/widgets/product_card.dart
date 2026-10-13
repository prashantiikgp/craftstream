import 'package:flutter/material.dart';

import '../../../data/generated/models.dart';
import '../../../shared/widgets/ds.dart';

/// Grid card: poster (never video), title, artisan and price. Fixed text block so rows line up.
class ProductCard extends StatelessWidget {
  final ProductSummary product;
  final double posterAspectRatio;
  final VoidCallback onTap;
  const ProductCard({super.key, required this.product, required this.posterAspectRatio, required this.onTap});

  /// Height of the text block under the poster, for the grid's row height.
  static double infoHeight(BuildContext context) {
    final type = context.type, t = context.tokens;
    double line(TextStyle s) => MediaQuery.textScalerOf(context).scale(s.fontSize!) * (s.height ?? 1.3);
    return 2 * t.space.md + 2 * line(type.title) + t.space.xs + line(type.caption) + t.space.sm + line(type.price);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: '${product.title}, ${product.artisanName}, ${formatMoney(product.price, product.currency)}',
      child: AppCard(
        variant: CardVariant.interactive,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius.md - 1)),
              child: AspectRatio(
                aspectRatio: posterAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductPoster(tags: product.tags, thumbnailUrl: product.thumbnailUrl, showMark: true),
                    Positioned(left: t.space.sm, bottom: t.space.sm, child: const _VideoPill()),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(t.space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height:
                        2 *
                        MediaQuery.textScalerOf(context).scale(context.type.title.fontSize!) *
                        (context.type.title.height ?? 1.3),
                    child: Text(product.title, style: context.type.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(height: t.space.xs),
                  Text(
                    product.artisanName,
                    style: context.type.caption.copyWith(color: t.sub),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: t.space.sm),
                  PriceText(product.price, currency: product.currency),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPill extends StatelessWidget {
  const _VideoPill();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.sm, vertical: t.space.xxs),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(t.radius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, size: 14, color: t.brandInk),
          SizedBox(width: t.space.xxs),
          Text(context.s('discover.card_video'), style: context.type.caption.copyWith(color: t.ink)),
        ],
      ),
    );
  }
}

/// Same footprint as ProductCard while results load.
class ProductCardSkeleton extends StatelessWidget {
  final double posterAspectRatio;
  const ProductCardSkeleton({super.key, required this.posterAspectRatio});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: posterAspectRatio,
            child: Skeleton(height: double.infinity, radius: t.radius.md - 1),
          ),
          Padding(
            padding: EdgeInsets.all(t.space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(height: 14),
                SizedBox(height: t.space.sm),
                const Skeleton(width: 90, height: 12),
                SizedBox(height: t.space.md),
                const Skeleton(width: 60, height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
