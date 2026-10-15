/// Builders for the activity log bricks in bricks.yml: log_bar (count or listing, refresh) and log_row (one entry,
/// tap for its details).
library;

import 'package:flutter/material.dart';

import '../../domain/ui/bricks_engine.dart';
import '../screens/screen_scope.dart';
import '../theme/app_theme.dart';
import 'kit.dart';

Widget logBarBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'log_bar');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final strings = configOf(context).strings;
  final info = scope.lookup(n.need('bind'));
  final m = info is Map ? info : const {};
  final count = m['count'] as int? ?? 0;
  final productId = m['product_id'] as String?;
  final brand = t.tone('brand');
  final countText = strings.get(n.need<String>(count == 1 ? 'one' : (m['has_more'] == true ? 'more' : 'many')), {
    'count': count,
  });
  final refreshLabel = say(context, n.need('refresh'));
  return Row(
    children: [
      Expanded(
        child: Wrap(
          spacing: s.space('gap'),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (productId != null)
              StyledText(strings.get(n.need('listing'), {'id': productId}), style: s.name('listing')),
            StyledText(countText, style: s.name('count'), color: s.color('count_color')),
            if (productId != null)
              Pressable(
                accent: brand.fill,
                semanticLabel: say(context, n.need('clear')),
                onTap: () => scope.act(context, n.prop<ActionSpec>('clear_action')),
                builder: (context, active) => StyledText(
                  say(context, n.need('clear')),
                  style: s.name('link'),
                  color: active ? t.text : brand.ink,
                ),
              ),
          ],
        ),
      ),
      SizedBox(width: s.space('gap')),
      Tooltip(
        message: refreshLabel,
        child: Pressable(
          accent: brand.fill,
          semanticLabel: refreshLabel,
          onTap: m['refreshing'] == true ? null : () => scope.act(context, n.prop<ActionSpec>('action')),
          builder: (context, active) => TapTarget(
            child: Container(
              width: s.number('box'),
              height: s.number('box'),
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: active ? brand.line : s.color('border'))),
              child: YamlIcon(s.name('refresh_icon'), size: s.number('icon'), color: t.text),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget logRowBrick(BuildContext context, BrickNode n) => _LogRow(n);

class _LogRow extends StatefulWidget {
  final BrickNode n;
  const _LogRow(this.n);

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.n;
    final s = BrickStyle.of(context, 'log_row');
    final scope = BrickScope.of(context);
    final t = context.tokens;
    final strings = configOf(context).strings;
    final e = scope.lookup(n.need('bind'));
    if (e is! Map) return const SizedBox.shrink();
    final tone = t.tone('${e['tone']}');
    final details = [for (final d in (e['details'] as List? ?? const [])) d as Map];
    final productId = e['product_id'] as String?;
    final orderId = e['order_id'] as String?;
    final message = '${e['message']}';
    final meta = StyledText(
      '${e['date']} ${e['time']} · ${e['event']}',
      style: s.name('meta'),
      color: s.color('meta_color'),
    );
    final hasAction = n.prop<ActionSpec>('action') != null;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StyledText('${e['level_label']}', style: s.name('level'), color: tone.ink),
            const Spacer(),
            if (details.isNotEmpty)
              YamlIcon(
                s.name(_open ? 'open_icon' : 'closed_icon'),
                size: s.number('icon'),
                color: s.color('meta_color'),
              ),
          ],
        ),
        SizedBox(height: s.space('gap')),
        StyledText(message, style: s.name('message')),
        SizedBox(height: s.space('gap')),
        Wrap(
          spacing: s.space('detail_gap'),
          runSpacing: s.space('gap'),
          children: [
            meta,
            if (productId != null)
              hasAction
                  ? Pressable(
                      accent: tone.fill,
                      semanticLabel: strings.get(n.need('listing'), {'id': productId}),
                      onTap: () => scope.act(context, n.prop<ActionSpec>('action')),
                      builder: (context, active) => StyledText(
                        strings.get(n.need('listing'), {'id': productId}),
                        style: s.name('link'),
                        color: active ? t.text : tone.ink,
                      ),
                    )
                  : StyledText(
                      strings.get(n.need('listing'), {'id': productId}),
                      style: s.name('meta'),
                      color: s.color('meta_color'),
                    ),
            if (orderId != null)
              StyledText(
                strings.get(n.need('order'), {'id': orderId}),
                style: s.name('meta'),
                color: s.color('meta_color'),
              ),
          ],
        ),
        if (_open && details.isNotEmpty) ...[
          SizedBox(height: s.space('detail_gap')),
          for (final d in details)
            Padding(
              padding: EdgeInsets.only(top: s.space('gap')),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StyledText('${d['key']}', style: s.name('detail_key'), color: s.color('detail_color')),
                  SizedBox(width: s.space('detail_gap')),
                  Expanded(child: StyledText('${d['value']}', style: s.name('detail_value'))),
                ],
              ),
            ),
        ],
      ],
    );

    return Pressable(
      accent: tone.fill,
      semanticLabel: message,
      onTap: details.isEmpty ? null : () => setState(() => _open = !_open),
      builder: (context, active) => Container(
        decoration: BoxDecoration(
          color: s.color('background'),
          border: Border.all(color: active ? tone.line : s.color('border')),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: s.number('bar'), color: tone.fill),
              Expanded(
                child: Padding(padding: EdgeInsets.all(s.space('padding')), child: body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
