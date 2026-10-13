/// The artisan's listings (created from this device) with their video status.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/generated/models.dart';
import '../../data/providers.dart';

final myProductsProvider = FutureProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(uploadRepositoryProvider).myProducts(),
);
