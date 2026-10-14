/// Data for ui/screens/studio.yml: the artisan's listings (models/product.yml fields), newest first.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/screens/screen_scope.dart';
import 'studio_controller.dart';

const studioCalls = {'refresh'};

ScreenData studioSource(WidgetRef ref, Map<String, String> params) {
  final products = ref.watch(myProductsProvider);
  final calls = <String, Object? Function(Object?)>{'refresh': (_) => ref.invalidate(myProductsProvider)};
  return switch (products) {
    AsyncData(:final value) => ScreenData(value.isEmpty ? SourceState.empty : SourceState.ready, {
        'studio': {'items': [for (final p in value) p.toJson()], 'count': value.length},
      }, calls),
    AsyncError() => ScreenData(SourceState.error, const {}, calls),
    _ => ScreenData(SourceState.loading, const {}, calls),
  };
}
