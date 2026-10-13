/// Which side of the marketplace the user is on, and the navigation for each side. Derived from the
/// route, so a deep link or the back button always shows the right navigation.
library;

import 'package:flutter/material.dart';

enum Role { buyer, artisan }

class Destination {
  final String path;
  final String labelKey;
  final IconData icon, selectedIcon;
  const Destination(this.path, this.labelKey, this.icon, this.selectedIcon);
}

const _buyer = [
  Destination('/discover', 'nav.discover', Icons.explore_outlined, Icons.explore),
  Destination('/orders', 'nav.orders', Icons.receipt_long_outlined, Icons.receipt_long),
];

const _artisan = [
  Destination('/studio', 'nav.my_products', Icons.storefront_outlined, Icons.storefront),
  Destination('/studio/new', 'nav.new_product', Icons.add_circle_outline, Icons.add_circle),
];

Role roleForLocation(String location) => location.startsWith('/studio') ? Role.artisan : Role.buyer;

List<Destination> destinationsFor(Role role) => role == Role.artisan ? _artisan : _buyer;

/// The destination whose path matches the location best (longest prefix wins).
int selectedDestination(List<Destination> destinations, String location) {
  var best = 0, bestLen = -1;
  for (var i = 0; i < destinations.length; i++) {
    final p = destinations[i].path;
    if ((location == p || location.startsWith('$p/')) && p.length > bestLen) {
      best = i;
      bestLen = p.length;
    }
  }
  return best;
}
