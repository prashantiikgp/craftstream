/// Data for ui/screens/product.yml: one product (models/product.yml fields) plus `ready` / `not_ready` from the
/// video status (status.yml `orderable`), and the calls its bricks make.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../shared/screens/screen_scope.dart';
import '../discover/discover_controller.dart';
import 'product_controller.dart';

const productCalls = {'show_tag', 'retry'};

ScreenData productSource(WidgetRef ref, Map<String, String> params) {
  final id = params['id'] ?? '';
  final product = ref.watch(productProvider(id));
  final status = ref.watch(appConfigProvider).status;
  final calls = <String, void Function(Object?)>{
    // A tag on the product page filters Browse to it (the screen's action then goes to /discover).
    'show_tag': (tag) => ref.read(discoverControllerProvider.notifier).showTag('$tag'),
    'retry': (_) => ref.invalidate(productProvider(id)),
  };
  return switch (product) {
    AsyncData(:final value) => ScreenData.ready({
        'product': {
          ...value.toJson(),
          'ready': status.orderable(value.videoStatus),
          'not_ready': !status.orderable(value.videoStatus),
        },
      }, calls),
    AsyncError() => ScreenData(SourceState.error, const {}, calls),
    _ => ScreenData(SourceState.loading, const {}, calls),
  };
}
