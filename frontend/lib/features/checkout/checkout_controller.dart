/// Checkout form state and submission. Limits come from models/order.yml via the generated OrderLimits;
/// the API validates again and computes the real total.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/generated/api_client.dart';
import '../../data/generated/limits.dart';
import '../../data/generated/models.dart';
import '../../data/providers.dart';
import '../orders/orders_controller.dart';

enum NameProblem { tooShort, tooLong }

class CheckoutState {
  final String name;
  final int quantity;
  final bool showErrors;
  final bool submitting;
  final String? submitError;
  const CheckoutState({
    this.name = '',
    this.quantity = 1,
    this.showErrors = false,
    this.submitting = false,
    this.submitError,
  });

  NameProblem? get nameProblem {
    final n = name.trim().length;
    if (n < OrderLimits.buyerNameMinLength) return NameProblem.tooShort;
    if (n > OrderLimits.buyerNameMaxLength) return NameProblem.tooLong;
    return null;
  }

  bool get valid => nameProblem == null;

  double totalFor(double unitPrice) => (unitPrice * quantity * 100).round() / 100;

  CheckoutState copyWith({
    String? name,
    int? quantity,
    bool? showErrors,
    bool? submitting,
    String? Function()? submitError,
  }) => CheckoutState(
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    showErrors: showErrors ?? this.showErrors,
    submitting: submitting ?? this.submitting,
    submitError: submitError == null ? this.submitError : submitError(),
  );
}

class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();

  void setName(String name) => state = state.copyWith(name: name, submitError: () => null);

  void setQuantity(int q) =>
      state = state.copyWith(quantity: q.clamp(OrderLimits.quantityMin, OrderLimits.quantityMax));

  /// Places the order. Returns it on success; on failure keeps the form and sets [CheckoutState.submitError].
  Future<Order?> place(Product product) async {
    if (!state.valid) {
      state = state.copyWith(showErrors: true);
      return null;
    }
    state = state.copyWith(submitting: true, submitError: () => null);
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .place(OrderCreate(productId: product.id, buyerName: state.name.trim(), quantity: state.quantity));
      ref
          .read(ordersControllerProvider.notifier)
          .add(PlacedOrder(order: order, productTitle: product.title, artisanName: product.artisanName));
      if (ref.mounted) state = state.copyWith(submitting: false);
      return order;
    } catch (e) {
      final message = e is ApiException ? e.error?.message : null;
      if (ref.mounted) state = state.copyWith(submitting: false, submitError: () => message ?? '');
      return null;
    }
  }
}

final checkoutControllerProvider = NotifierProvider.autoDispose<CheckoutController, CheckoutState>(
  CheckoutController.new,
);
