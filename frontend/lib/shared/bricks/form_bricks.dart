/// Builders for the form bricks in bricks.yml: product_summary, text_field, stepper, amount_row.
library;

import 'package:flutter/material.dart';

import '../../domain/ui/bricks_engine.dart';
import '../format/money.dart';
import '../screens/screen_scope.dart';
import '../theme/app_theme.dart';
import 'kit.dart';

Widget productSummaryBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'product_summary');
  final p = BrickScope.of(context).lookup(n.need('bind'));
  if (p is! Map) return const SizedBox.shrink();
  final strings = configOf(context).strings;
  final price = formatMoney(p['price'] as num? ?? 0, '${p['currency']}');
  return Container(
    padding: EdgeInsets.all(s.space('padding')),
    decoration: BoxDecoration(color: s.color('background'), border: Border.all(color: s.color('border'))),
    child: Row(children: [
      SizedBox.square(
        dimension: s.number('poster'),
        child: Poster(seed: '${p['id']}', thumbnailUrl: p['thumbnail_url'] as String?),
      ),
      SizedBox(width: s.space('gap')),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StyledText('${p['title'] ?? ''}', style: s.name('title'), maxLines: s.number('title_lines').toInt()),
          StyledText(strings.get(n.need('artisan'), {'artisan': '${p['artisan_name'] ?? ''}'}),
              style: s.name('artisan'), color: s.color('artisan_color')),
          StyledText(strings.get(n.need('each'), {'price': price}), style: s.name('each'), color: s.color('each_color')),
        ]),
      ),
    ]),
  );
}

Widget textFieldBrick(BuildContext context, BrickNode n) => _TextField(n);

class _TextField extends StatefulWidget {
  final BrickNode n;
  const _TextField(this.n);

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  final _text = TextEditingController();
  String? _external;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.n;
    final s = BrickStyle.of(context, 'text_field');
    final scope = BrickScope.of(context);
    final t = context.tokens;
    final current = '${scope.lookup(n.need('bind')) ?? ''}';
    if (current != _external) {
      _external = current;
      if (_text.text != current) _text.text = current;
    }
    // The source gives an error as {key, args} (strings.yml), or null.
    final err = n.prop<String>('error') == null ? null : scope.lookup(n.need('error'));
    final error = err is Map ? configOf(context).strings.get('${err['key']}', {
      for (final e in ((err['args'] as Map?) ?? const {}).entries) '${e.key}': e.value as Object,
    }) : null;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(s.radius('radius')),
          borderSide: BorderSide(color: c, width: t.focusRingWidth / 2),
        );
    final lines = (n.prop<num>('lines') ?? 1).toInt();
    final prefix = n.prop<String>('prefix'), helper = n.prop<String>('helper');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StyledText(say(context, n.need('label')), style: s.name('label'), color: s.color('label_color')),
      SizedBox(height: s.space('gap')),
      TextField(
        controller: _text,
        onChanged: (v) => scope.act(context, n.prop<ActionSpec>('action'), v),
        style: s.text('text'),
        minLines: lines,
        maxLines: lines,
        keyboardType: switch (n.need<String>('keyboard')) {
          'decimal' => const TextInputType.numberWithOptions(decimal: true),
          _ => lines > 1 ? TextInputType.multiline : TextInputType.text,
        },
        decoration: InputDecoration(
          prefixIcon: prefix == null
              ? null
              : Align(widthFactor: 1, child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: s.space('padding')),
                  child: StyledText(say(context, prefix), style: s.name('prefix_style'), color: s.color('prefix_color')),
                )),
          helperText: helper == null ? null : say(context, helper, args: n.prop('helper_args')),
          helperStyle: s.text('error').copyWith(color: s.color('label_color')),
          helperMaxLines: lines + 1,
          hintText: say(context, n.need('hint')),
          hintStyle: s.text('text').copyWith(color: s.color('hint')),
          filled: true,
          fillColor: s.color('background'),
          contentPadding: EdgeInsets.symmetric(horizontal: s.space('padding'), vertical: s.space('padding')),
          border: border(s.color('border')),
          enabledBorder: border(s.color('border')),
          focusedBorder: border(s.color('focus')),
          errorBorder: border(s.color('error_color')),
          focusedErrorBorder: border(s.color('error_color')),
          errorText: error,
          errorStyle: s.text('error').copyWith(color: s.color('error_color')),
        ),
      ),
    ]);
  }
}

Widget stepperBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'stepper');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final value = scope.lookup(n.need('bind')) as int? ?? 0;
  final min = scope.lookup(n.need('min')) as int? ?? value, max = scope.lookup(n.need('max')) as int? ?? value;
  final brand = t.tone('brand');
  Widget button(String icon, String label, int next, bool enabled) => Tooltip(
        message: label,
        child: Pressable(
          accent: brand.fill,
          semanticLabel: label,
          onTap: enabled ? () => scope.act(context, n.prop<ActionSpec>('action'), next) : null,
          builder: (context, _) => SizedBox(
            width: s.number('button'),
            height: s.number('height'),
            child: Center(child: YamlIcon(icon, size: s.number('icon'), color: enabled ? t.text : s.color('disabled'))),
          ),
        ),
      );
  final limit = n.prop<String>('limit');
  return Row(children: [
    Container(
      decoration: BoxDecoration(color: s.color('background'), border: Border.all(color: s.color('border'))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        button(s.name('less_icon'), say(context, n.need('less')), value - 1, value > min),
        SizedBox(
          width: s.number('value_width'),
          child: StyledText('$value', style: s.name('value'), align: TextAlign.center),
        ),
        button(s.name('more_icon'), say(context, n.need('more')), value + 1, value < max),
      ]),
    ),
    if (limit != null) ...[
      SizedBox(width: s.space('gap')),
      Flexible(
        child: StyledText(configOf(context).strings.get(limit, {'max': max}),
            style: s.name('limit'), color: s.color('limit_color')),
      ),
    ],
  ]);
}

Widget amountRowBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'amount_row');
  final scope = BrickScope.of(context);
  final amount = scope.lookup(n.need('bind')) as num? ?? 0;
  return Container(
    padding: EdgeInsets.only(top: s.space('padding')),
    decoration: BoxDecoration(border: Border(top: BorderSide(color: s.color('border')))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
      Expanded(child: StyledText(say(context, n.need('label')), style: s.name('label'), color: s.color('label_color'))),
      StyledText(formatMoney(amount, '${scope.lookup(n.need('currency'))}'), style: s.name('amount'),
          color: s.color('amount_color')),
    ]),
  );
}
