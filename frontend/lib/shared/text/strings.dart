/// `context.s('group.key', {'name': value})`: every user-visible string comes from assets/config/ui/strings.yml.
/// Keys must be string literals so `test/domain/ui/strings_usage_test.dart` can check them.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';

extension StringsContext on BuildContext {
  String s(String key, [Map<String, Object> args = const {}]) =>
      ProviderScope.containerOf(this, listen: false).read(appConfigProvider).strings.get(key, args);
}
