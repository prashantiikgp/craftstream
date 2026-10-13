/// One product with its video status and HLS URL.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/generated/models.dart';
import '../../data/providers.dart';

final productProvider = FutureProvider.autoDispose.family<Product, String>(
  (ref, id) => ref.watch(catalogRepositoryProvider).product(id),
);
