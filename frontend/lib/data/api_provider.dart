/// The generated API client, pointed at this environment's API host, and the HTTP client it shares with
/// the resumable uploader (tests override [httpClientProvider] with a fake server).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'generated/api_client.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final env = ref.watch(appConfigProvider).env;
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  return ApiClient(env.apiHostFor(isAndroid: isAndroid).toString(), client: ref.watch(httpClientProvider));
});
