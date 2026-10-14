/// Data for ui/screens/checkout.yml: the product being ordered, the form (name, quantity within OrderLimits from
/// models/order.yml), the total, and the calls. `place` answers the new order's id, so the screen can go to its
/// receipt (`then: {go: /placed/{result}}`), or false when the order did not go through.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/generated/limits.dart';
import '../../shared/format/money.dart';
import '../../shared/screens/screen_scope.dart';
import '../product/product_controller.dart';
import 'checkout_controller.dart';

const checkoutCalls = {'set_name', 'set_quantity', 'place', 'retry'};

ScreenData checkoutSource(WidgetRef ref, Map<String, String> params) {
  final id = params['id'] ?? '';
  final product = ref.watch(productProvider(id));
  final form = ref.watch(checkoutControllerProvider);
  final controller = ref.read(checkoutControllerProvider.notifier);
  final calls = <String, Object? Function(Object?)>{
    'set_name': (v) => controller.setName('${v ?? ''}'),
    'set_quantity': (v) => controller.setQuantity(v is int ? v : int.tryParse('$v') ?? form.quantity),
    'place': (_) async {
      final p = product.value;
      if (p == null) return false;
      final order = await controller.place(p);
      return order?.id ?? false;
    },
    'retry': (_) => ref.invalidate(productProvider(id)),
  };
  final p = product.value;
  if (p == null) return ScreenData(product.hasError ? SourceState.error : SourceState.loading, const {}, calls);
  final nameError = !form.showErrors
      ? null
      : switch (form.nameProblem) {
          NameProblem.tooShort => {'key': 'checkout.name_too_short', 'args': {'min': OrderLimits.buyerNameMinLength}},
          NameProblem.tooLong => {'key': 'checkout.name_too_long', 'args': {'max': OrderLimits.buyerNameMaxLength}},
          null => null,
        };
  return ScreenData.ready({
    'checkout': {
      'product': p.toJson(),
      'name': form.name,
      'name_error': nameError,
      'quantity': form.quantity,
      'min': OrderLimits.quantityMin,
      'max': OrderLimits.quantityMax,
      'total': form.totalFor(p.price),
      'currency': p.currency,
      'unit_price': formatMoney(p.price, p.currency),
      'submitting': form.submitting,
      'failed': form.submitError != null,
      // The API's own message when it gave one; empty -> the screen's generic message.
      'failure': form.submitError,
    },
  }, calls);
}
