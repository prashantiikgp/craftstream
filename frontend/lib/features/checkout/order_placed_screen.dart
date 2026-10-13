/// The end of the buyer flow: "Order placed" with the order id and what happens next.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../shared/widgets/ds.dart';
import '../orders/orders_controller.dart';

class OrderPlacedScreen extends ConsumerWidget {
  final String orderId;
  const OrderPlacedScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final placed = ref.watch(ordersControllerProvider.notifier).byId(orderId);
    ref.watch(ordersControllerProvider);
    final formWidth = ref.watch(appConfigProvider).layout.rules.formMaxWidth;

    Widget row(String label, Widget value) => Padding(
          padding: EdgeInsets.symmetric(vertical: t.space.xs),
          child: Row(children: [
            Expanded(child: Text(label, style: context.type.body.copyWith(color: t.sub))),
            value,
          ]),
        );

    return Scaffold(
      body: SafeArea(
        child: PageScroll(maxWidth: formWidth, children: [
          SizedBox(height: t.space.xxl),
          const Center(child: SpotIllustration(SpotKind.orderPlaced, width: 180)),
          SizedBox(height: t.space.xl),
          Text(context.s('placed.title'), textAlign: TextAlign.center, style: context.type.h1),
          SizedBox(height: t.space.sm),
          Text(
            placed == null
                ? context.s('placed.message_generic')
                : context.s('placed.message', {'artisan': placed.artisanName}),
            textAlign: TextAlign.center,
            style: context.type.body.copyWith(color: t.sub),
          ),
          SizedBox(height: t.space.xl),
          AppCard(
            child: Column(children: [
              row(context.s('placed.order_id'), SelectableText(orderId, style: context.type.label)),
              if (placed != null) ...[
                row(context.s('placed.product'),
                    Flexible(child: Text(placed.productTitle, style: context.type.label, textAlign: TextAlign.end))),
                row(context.s('placed.quantity'), Text('${placed.order.quantity}', style: context.type.label)),
                row(context.s('placed.total'), PriceText(placed.order.total, currency: placed.order.currency)),
                row(context.s('placed.status'), StatusBadge(context.s('placed.status_placed'), tone: Tone.success, dot: true)),
              ],
            ]),
          ),
          SizedBox(height: t.space.xl),
          AppButton(context.s('placed.keep_exploring'),
              size: ButtonSize.lg, expand: true, onPressed: () => context.go('/discover')),
          SizedBox(height: t.space.sm),
          AppButton(context.s('placed.see_orders'),
              variant: ButtonVariant.ghost, expand: true, onPressed: () => context.go('/orders')),
        ]),
      ),
    );
  }
}
