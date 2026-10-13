/// The generated API client, pointed at this environment's API host.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import 'generated/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final env = ref.watch(appConfigProvider).env;
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  return ApiClient(env.apiHostFor(isAndroid: isAndroid).toString());
});
