/// Orders placed from this device (session only; see orders_controller.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/ds.dart';
import 'orders_controller.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final orders = ref.watch(ordersControllerProvider);
    return PageScroll(children: [
      SectionHeader(context.s('orders.title'), subtitle: context.s('orders.subtitle')),
      SizedBox(height: t.space.sm),
      if (orders.isEmpty)
        EmptyState(
          icon: Icons.receipt_long_outlined,
          title: context.s('orders.empty_title'),
          message: context.s('orders.empty_message'),
          action: AppButton(context.s('orders.start_exploring'), onPressed: () => context.go('/discover')),
        )
      else
        for (final o in orders) ...[
          AppCard(
            variant: CardVariant.interactive,
            onTap: () => context.push('/placed/${o.order.id}'),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.productTitle, style: context.type.title),
                  SizedBox(height: t.space.xxs),
                  Text(
                    context.s('orders.line', {'quantity': o.order.quantity, 'artisan': o.artisanName}),
                    style: context.type.caption.copyWith(color: t.sub),
                  ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                PriceText(o.order.total, currency: o.order.currency, style: context.type.title),
                SizedBox(height: t.space.xxs),
                StatusBadge(context.s('placed.status_placed'), tone: Tone.success, dot: true),
              ]),
            ]),
          ),
          SizedBox(height: t.space.md),
        ],
    ]);
  }
}
