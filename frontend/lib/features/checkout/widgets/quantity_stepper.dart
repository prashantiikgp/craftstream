import 'package:flutter/material.dart';

import '../../../shared/widgets/ds.dart';

/// − n + with the limits enforced by disabling the buttons.
class QuantityStepper extends StatelessWidget {
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const QuantityStepper({super.key, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget button(IconData icon, String tooltip, int next, bool enabled) => IconButton(
          tooltip: tooltip,
          onPressed: enabled ? () => onChanged(next) : null,
          icon: Icon(icon, color: enabled ? t.brandInk : t.faint),
        );
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.hair),
        borderRadius: BorderRadius.circular(t.radius.sm),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        button(Icons.remove, context.s('checkout.decrease'), value - 1, value > min),
        SizedBox(
          width: 40,
          child: Text('$value', textAlign: TextAlign.center, style: context.type.title),
        ),
        button(Icons.add, context.s('checkout.increase'), value + 1, value < max),
      ]),
    );
  }
}
