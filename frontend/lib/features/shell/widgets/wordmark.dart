import 'package:flutter/material.dart';

import '../../../shared/widgets/ds.dart';

/// The CraftStream lockup in the app bar, slightly smaller on phones. Scales down rather than overflow
/// when the Buy/Sell switch leaves little room (large text settings, narrow phones).
class Wordmark extends StatelessWidget {
  final bool compact;
  const Wordmark({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: BrandLockup(height: compact ? 26 : 30),
      );
}
