/// Checkout: name + quantity, live total, Place order. No payment and no address: the flow ends at
/// "Order placed" and the artisan arranges delivery.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../data/generated/limits.dart';
import '../../data/generated/models.dart';
import '../../shared/widgets/ds.dart';
import '../product/product_controller.dart';
import 'checkout_controller.dart';
import 'widgets/quantity_stepper.dart';

class CheckoutScreen extends ConsumerWidget {
  final String productId;
  const CheckoutScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));
    final formWidth = ref.watch(appConfigProvider).layout.rules.formMaxWidth;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.s('common.back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/product/$productId'),
        ),
        title: Text(context.s('checkout.title')),
      ),
      body: switch (product) {
        AsyncData(:final value) => PageScroll(
          maxWidth: formWidth,
          children: [_Form(product: value)],
        ),
        AsyncError() => PageScroll(
          maxWidth: formWidth,
          children: [LoadError(onRetry: () => ref.invalidate(productProvider(productId)))],
        ),
        _ => PageScroll(
          maxWidth: formWidth,
          children: [
            const Skeleton(height: 96),
            SizedBox(height: context.tokens.space.xl),
            const Skeleton(height: 48),
            SizedBox(height: context.tokens.space.xl),
            const Skeleton(height: 48),
          ],
        ),
      },
    );
  }
}

class _Form extends ConsumerWidget {
  final Product product;
  const _Form({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(checkoutControllerProvider);
    final controller = ref.read(checkoutControllerProvider.notifier);

    Future<void> submit() async {
      final order = await controller.place(product);
      if (order != null && context.mounted) context.go('/placed/${order.id}');
    }

    final nameError = !state.showErrors
        ? null
        : switch (state.nameProblem) {
            NameProblem.tooShort => context.s('checkout.name_too_short', {'min': OrderLimits.buyerNameMinLength}),
            NameProblem.tooLong => context.s('checkout.name_too_long', {'max': OrderLimits.buyerNameMaxLength}),
            null => null,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Summary(product: product),
        SizedBox(height: t.space.xl),
        AppTextField(
          label: context.s('checkout.name_label'),
          hint: context.s('checkout.name_hint'),
          error: nameError,
          onChanged: controller.setName,
        ),
        SizedBox(height: t.space.lg),
        Text(context.s('checkout.quantity_label'), style: context.type.label),
        SizedBox(height: t.space.xs),
        Row(
          children: [
            QuantityStepper(
              value: state.quantity,
              min: OrderLimits.quantityMin,
              max: OrderLimits.quantityMax,
              onChanged: controller.setQuantity,
            ),
            SizedBox(width: t.space.md),
            Flexible(
              child: Text(
                context.s('checkout.quantity_limit', {'max': OrderLimits.quantityMax}),
                style: context.type.caption.copyWith(color: t.sub),
              ),
            ),
          ],
        ),
        SizedBox(height: t.space.xl),
        Divider(color: t.hair, height: 1),
        SizedBox(height: t.space.lg),
        Row(
          children: [
            Expanded(child: Text(context.s('checkout.total'), style: context.type.h3)),
            PriceText(state.totalFor(product.price), currency: product.currency, style: context.type.h2),
          ],
        ),
        SizedBox(height: t.space.xs),
        Text(
          context.s('checkout.total_note', {
            'quantity': state.quantity,
            'price': formatMoney(product.price, product.currency),
          }),
          style: context.type.caption.copyWith(color: t.sub),
        ),
        if (state.submitError != null) ...[
          SizedBox(height: t.space.lg),
          Notice(
            tone: Tone.danger,
            title: context.s('checkout.failed_title'),
            message: state.submitError!.isEmpty ? context.s('checkout.failed_message') : state.submitError,
          ),
        ],
        SizedBox(height: t.space.xl),
        AppButton(
          context.s('checkout.place_order'),
          size: ButtonSize.lg,
          expand: true,
          loading: state.submitting,
          onPressed: submit,
        ),
        SizedBox(height: t.space.md),
        Text(
          context.s('checkout.no_payment_note'),
          textAlign: TextAlign.center,
          style: context.type.caption.copyWith(color: t.sub),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final Product product;
  const _Summary({required this.product});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(t.radius.sm),
            child: SizedBox.square(
              dimension: 72,
              child: ProductPoster(tags: product.tags, thumbnailUrl: product.thumbnailUrl),
            ),
          ),
          SizedBox(width: t.space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.title, style: context.type.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                SizedBox(height: t.space.xxs),
                Text(
                  context.s('product.by_artisan', {'artisan': product.artisanName}),
                  style: context.type.caption.copyWith(color: t.sub),
                ),
                SizedBox(height: t.space.xs),
                Text(
                  context.s('checkout.each', {'price': formatMoney(product.price, product.currency)}),
                  style: context.type.label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
