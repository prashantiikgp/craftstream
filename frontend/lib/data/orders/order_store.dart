/// Where the device keeps its orders between visits: shared preferences (localStorage on the web). Each entry is
/// one JSON string; orders.yml says the key and how many to keep.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';

abstract interface class OrderStore {
  Future<List<String>> read();
  Future<void> write(List<String> entries);
}

class PrefsOrderStore implements OrderStore {
  final String key;
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  PrefsOrderStore(this.key);

  @override
  Future<List<String>> read() async => await _prefs.getStringList(key) ?? const [];

  @override
  Future<void> write(List<String> entries) => _prefs.setStringList(key, entries);
}

/// For tests: forgets everything when the process ends.
class MemoryOrderStore implements OrderStore {
  List<String> entries = const [];

  @override
  Future<List<String>> read() async => entries;

  @override
  Future<void> write(List<String> entries) async => this.entries = entries;
}

final orderStoreProvider =
    Provider<OrderStore>((ref) => PrefsOrderStore(ref.watch(appConfigProvider).orders.storageKey));
