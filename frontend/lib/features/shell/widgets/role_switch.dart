import 'package:flutter/material.dart';

import '../../../shared/widgets/ds.dart';
import '../shell_controller.dart';

/// Buy | Sell. There are no accounts: this switch is how a reviewer moves between buyer and artisan.
class RoleSwitch extends StatelessWidget {
  final Role role;
  final ValueChanged<Role> onChanged;
  const RoleSwitch({super.key, required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context) => SegmentedButton<Role>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          ButtonSegment(value: Role.buyer, label: Text(context.s('shell.role_buyer'))),
          ButtonSegment(value: Role.artisan, label: Text(context.s('shell.role_artisan'))),
        ],
        selected: {role},
        onSelectionChanged: (s) => onChanged(s.first),
      );
}
