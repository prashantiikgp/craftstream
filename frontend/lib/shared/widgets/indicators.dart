/// Small indicators: StatusBadge (state), TagChip (filters), PriceText (money), AppTextField (labelled input).
library;

import 'package:flutter/material.dart';

import '../format/money.dart';
import '../theme/app_theme.dart';
import 'tone.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Tone tone;
  final bool dot;
  const StatusBadge(this.label, {super.key, this.tone = Tone.neutral, this.dot = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = toneColors(t, tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.sm, vertical: t.space.xxs),
      decoration: BoxDecoration(color: c.wash, borderRadius: BorderRadius.circular(t.radius.tag)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(width: 6, height: 6, decoration: BoxDecoration(color: c.fill, shape: BoxShape.circle)),
          SizedBox(width: t.space.xs),
        ],
        Text(label, style: context.type.caption.copyWith(color: c.ink)),
      ]),
    );
  }
}

class TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  const TagChip(this.label, {super.key, this.selected = false, this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? t.brandLl : t.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radius.pill),
          side: BorderSide(color: selected ? t.brandLine : t.hair),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radius.pill),
          onTap: onSelected == null ? null : () => onSelected!(!selected),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.md, vertical: t.space.xs + 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (selected) ...[Icon(Icons.check, size: 14, color: t.brandInk), SizedBox(width: t.space.xs)],
              Text(label, style: context.type.caption.copyWith(color: selected ? t.brandInk : t.ink)),
            ]),
          ),
        ),
      ),
    );
  }
}

class PriceText extends StatelessWidget {
  final num amount;
  final String currency;
  final TextStyle? style;
  const PriceText(this.amount, {super.key, this.currency = 'INR', this.style});

  @override
  Widget build(BuildContext context) =>
      Text(formatMoney(amount, currency), style: style ?? context.type.price);
}

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? helper;
  final String? error;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? prefix;
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.helper,
    this.error,
    this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: context.type.label),
      SizedBox(height: t.space.xs),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        style: context.type.body,
        decoration: InputDecoration(hintText: hint, helperText: helper, errorText: error, prefixIcon: prefix),
      ),
    ]);
  }
}
