import 'package:flutter/material.dart';

import '../../../data/generated/models.dart';
import '../../../shared/widgets/ds.dart';

/// One of the artisan's listings: poster, title, price, status and what the status means.
class ListingCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onOpen;
  final VoidCallback? onRetry;
  const ListingCard({super.key, required this.product, this.onOpen, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = product;
    final hint = switch (p.videoStatus) {
      'ready' => context.s('studio.hint_ready'),
      'processing' => context.s('studio.hint_processing'),
      'failed' => context.s('studio.hint_failed'),
      _ => context.s('studio.hint_awaiting_upload'),
    };
    return AppCard(
      variant: onOpen == null ? CardVariant.flat : CardVariant.interactive,
      onTap: onOpen,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(t.radius.sm),
          child: SizedBox.square(
            dimension: 88,
            child: ProductPoster(tags: p.tags, thumbnailUrl: p.thumbnailUrl),
          ),
        ),
        SizedBox(width: t.space.lg),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(p.title, style: context.type.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(width: t.space.sm),
              VideoStatusBadge(p.videoStatus),
            ]),
            SizedBox(height: t.space.xxs),
            PriceText(p.price, currency: p.currency, style: context.type.label),
            SizedBox(height: t.space.sm),
            Text(hint, style: context.type.caption.copyWith(color: t.sub)),
            if (p.videoStatus == 'processing') ...[
              SizedBox(height: t.space.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(t.radius.pill),
                child: const LinearProgressIndicator(minHeight: 4),
              ),
            ],
            if (p.videoStatus == 'failed' && onRetry != null) ...[
              SizedBox(height: t.space.xs),
              AppButton(context.s('studio.upload_again'),
                  onPressed: onRetry, variant: ButtonVariant.ghost, size: ButtonSize.sm, icon: Icons.refresh),
            ],
          ]),
        ),
      ]),
    );
  }
}
