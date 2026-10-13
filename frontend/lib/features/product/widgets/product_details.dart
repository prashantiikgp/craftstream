import 'package:flutter/material.dart';

import '../../../data/generated/models.dart';
import '../../../shared/widgets/ds.dart';

/// Title, artisan, price, tags and description. [buy] is shown inline (wide layouts); phones use a
/// sticky bottom bar instead.
class ProductDetails extends StatelessWidget {
  final Product product;
  final ValueChanged<String> onTag;
  final Widget? buy;
  const ProductDetails({super.key, required this.product, required this.onTag, this.buy});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = product;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (p.videoStatus != 'ready') ...[VideoStatusBadge(p.videoStatus), SizedBox(height: t.space.sm)],
      Text(p.title, style: context.type.h1),
      SizedBox(height: t.space.xs),
      Text(context.s('product.by_artisan', {'artisan': p.artisanName}),
          style: context.type.title.copyWith(color: t.sub)),
      SizedBox(height: t.space.lg),
      PriceText(p.price, currency: p.currency, style: context.type.h2),
      if (buy != null) ...[SizedBox(height: t.space.lg), buy!],
      SizedBox(height: t.space.xl),
      if (p.videoStatus != 'ready') ...[
        Notice(
          tone: Tone.warning,
          title: context.s('product.not_ready_title'),
          message: context.s('product.not_ready_message'),
        ),
        SizedBox(height: t.space.xl),
      ],
      Text(context.s('product.about'), style: context.type.h3),
      SizedBox(height: t.space.sm),
      Text(p.description, style: context.type.body),
      if (p.tags.isNotEmpty) ...[
        SizedBox(height: t.space.xl),
        Text(context.s('product.tags'), style: context.type.label.copyWith(color: t.sub)),
        SizedBox(height: t.space.sm),
        Wrap(spacing: t.space.sm, runSpacing: t.space.sm, children: [
          for (final tag in p.tags) TagChip(tag, onSelected: (_) => onTag(tag)),
        ]),
      ],
      SizedBox(height: t.space.xl),
      Notice(
        tone: Tone.info,
        icon: Icons.handshake_outlined,
        title: context.s('product.after_order_title'),
        message: context.s('product.after_order_message', {'artisan': p.artisanName}),
      ),
    ]);
  }
}
