/// Builders for the artisan-side bricks in bricks.yml: listing_card, tag_picker, video_pick, progress_bar, steps.
library;

import 'package:flutter/material.dart';

import '../../domain/ui/bricks_engine.dart';
import '../screens/screen_scope.dart';
import '../theme/app_theme.dart';
import 'kit.dart';

/// One of the artisan's products: poster, title, price, its video status (status.yml: tag, hint, progress bar,
/// "Upload again") and, when live, a way to open it.
Widget listingCardBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'listing_card');
  final scope = BrickScope.of(context);
  final config = configOf(context);
  final t = context.tokens;
  final p = scope.lookup(n.need('bind'));
  if (p is! Map) return const SizedBox.shrink();
  final look = config.status.look('video', '${p['video_status']}');
  final role = t.accent(config.navigation.role(n.need('role')).accent);
  final title = '${p['title'] ?? ''}';
  final orderable = config.status.orderable('${p['video_status']}');
  return Pressable(
    accent: role.fill,
    semanticLabel: config.strings.get('a11y.listing_card', {'title': title, 'status': config.strings.get(look.label)}),
    onTap: orderable ? () => scope.act(context, n.prop<ActionSpec>('open')) : null,
    builder: (context, active) => Container(
      decoration: BoxDecoration(
        color: s.color('background'),
        border: Border.all(color: active ? role.line : s.color('border')),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.all(s.space('padding')),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox.square(
              dimension: s.number('poster'),
              child: Poster(seed: '${p['id']}', thumbnailUrl: p['thumbnail_url'] as String?),
            ),
            SizedBox(width: s.space('gap')),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: StyledText(title, style: s.name('title'), maxLines: s.number('title_lines').toInt())),
                  SizedBox(width: s.space('gap')),
                  Flexible(child: StatusTag(kind: 'video', value: '${p['video_status']}', style: s.name('tag'))),
                ]),
                StyledText(configOf(context).format.money(p['price'] as num? ?? 0, '${p['currency']}'),
                    style: s.name('price'), color: s.color('price_color')),
                if (look.hint != null)
                  StyledText(config.strings.get(look.hint!), style: s.name('hint'), color: s.color('hint_color')),
              ]),
            ),
          ]),
        ),
        if (look.progress)
          Padding(
            padding: EdgeInsets.fromLTRB(s.space('padding'), 0, s.space('padding'), s.space('padding')),
            child: LinearProgressIndicator(
              minHeight: s.number('bar'),
              color: t.tone(look.tone).fill,
              backgroundColor: s.color('bar_track'),
            ),
          ),
        if (look.retry && n.prop<ActionSpec>('retry') != null)
          Padding(
            padding: EdgeInsets.fromLTRB(s.space('padding'), 0, s.space('padding'), s.space('padding')),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Pressable(
                accent: role.fill,
                semanticLabel: say(context, n.need('retry_label')),
                onTap: () => scope.act(context, n.prop<ActionSpec>('retry')),
                builder: (context, active) => Container(
                  padding: EdgeInsets.symmetric(horizontal: s.space('padding'), vertical: s.space('gap')),
                  decoration: BoxDecoration(border: Border.all(color: role.line)),
                  child: StyledText(say(context, n.need('retry_label')), style: s.name('retry_style')),
                ),
              ),
            ),
          ),
      ]),
    ),
  );
}

/// Tags to pick (several may be on). Each passes its value to `action` as item.value.
Widget tagPickerBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'tag_picker');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final role = t.accent(configOf(context).navigation.role(n.need('role')).accent);
  final tags = scope.lookup(n.need('bind'));
  return Wrap(spacing: s.space('gap'), runSpacing: s.space('gap'), children: [
    for (final (i, tag) in (tags is List ? tags : const []).indexed)
      scope.withItem(
        tag,
        i,
        Builder(builder: (context) {
          final on = (tag as Map)['selected'] == true;
          return Pressable(
            accent: role.fill,
            semanticLabel: '${tag['value']}',
            onTap: () => BrickScope.of(context).act(context, n.prop<ActionSpec>('action')),
            builder: (context, active) => Container(
              height: s.number('height'),
              padding: EdgeInsets.symmetric(horizontal: s.space('padding')),
              decoration: BoxDecoration(
                color: on ? role.fill : s.color('background'),
                border: Border.all(color: on || active ? role.line : s.color('border')),
              ),
              child: Align(
                widthFactor: 1,
                child: StyledText('${tag['value']}', style: s.name('label'), color: on ? role.onFill : t.text),
              ),
            ),
          );
        }),
      ),
  ]);
}

/// The process video to upload: a big "choose" area before one is picked, then its name, size and length with a
/// way to change it. The length check against the server's limit is shown by notices in the screen YAML.
Widget videoPickBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'video_pick');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final strings = configOf(context).strings;
  final role = t.accent(configOf(context).navigation.role(n.need('role')).accent);
  final v = scope.lookup(n.need('bind'));
  final m = v is Map ? v : const {};
  final picked = m['picked'] == true, missing = m['missing'] == true;
  Widget button(String label, {required bool filled}) => Pressable(
        accent: role.fill,
        semanticLabel: label,
        onTap: () => scope.act(context, n.prop<ActionSpec>('action')),
        builder: (context, active) => Container(
          padding: EdgeInsets.symmetric(horizontal: s.space('padding'), vertical: s.space('gap')),
          decoration: BoxDecoration(
            color: filled ? role.fill : s.color('background'),
            border: Border.all(color: filled || active ? role.line : s.color('border')),
          ),
          child: StyledText(label, style: s.name('button'), color: filled ? role.onFill : t.text),
        ),
      );
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    StyledText(say(context, n.need('label')), style: s.name('label_style'), color: s.color('label_color')),
    SizedBox(height: s.space('gap')),
    if (!picked) ...[
      Container(
        padding: EdgeInsets.all(s.space('area_padding')),
        decoration: BoxDecoration(
          color: role.wash,
          border: Border.all(color: missing ? t.tone('danger').line : role.line),
        ),
        child: Column(children: [
          YamlIcon(s.name('icon'), size: s.number('icon_size'), color: role.ink),
          SizedBox(height: s.space('gap')),
          StyledText(say(context, n.need('empty_title')), style: s.name('title'), align: TextAlign.center),
          SizedBox(height: s.space('gap')),
          StyledText(
            m['max'] == null ? say(context, n.need('empty_loading')) : strings.get(n.need('empty_message'), {'max': m['max']}),
            style: s.name('message'),
            color: s.color('message_color'),
            align: TextAlign.center,
          ),
          SizedBox(height: s.space('area_padding')),
          button(say(context, n.need('choose')), filled: true),
        ]),
      ),
      if (missing) ...[
        SizedBox(height: s.space('gap')),
        StyledText(say(context, n.need('required')), style: s.name('message'), color: t.tone('danger').ink),
      ],
    ] else
      Container(
        padding: EdgeInsets.all(s.space('padding')),
        decoration: BoxDecoration(color: s.color('background'), border: Border.all(color: s.color('border'))),
        child: Row(children: [
          Container(
            width: s.number('file_box'),
            height: s.number('file_box'),
            color: t.accent(s.name('file_accent')).fill,
            alignment: Alignment.center,
            child: YamlIcon(s.name('icon'), size: s.number('file_icon'), color: t.accent(s.name('file_accent')).onFill),
          ),
          SizedBox(width: s.space('gap')),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              StyledText('${m['name'] ?? ''}', style: s.name('title'), maxLines: 1),
              StyledText('${m['details'] ?? ''}', style: s.name('details'), color: s.color('message_color')),
            ]),
          ),
          SizedBox(width: s.space('gap')),
          button(say(context, n.need('change')), filled: false),
        ]),
      ),
  ]);
}

/// A progress bar for a bound fraction (0–1); moving without a value while `indeterminate` is true.
Widget progressBarBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'progress_bar');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final indeterminate = n.prop<String>('indeterminate') != null && truthy(scope.lookup(n.need('indeterminate')));
  final value = scope.lookup(n.need('bind')) as num? ?? 0;
  final role = n.prop<String>('role');
  final color = role == null ? t.tone(n.need('tone')).fill : t.accent(configOf(context).navigation.role(role).accent).fill;
  return LinearProgressIndicator(
    value: indeterminate ? null : value.toDouble(),
    minHeight: s.number(n.need('size')),
    color: color,
    backgroundColor: s.color('track'),
  );
}

/// Numbered steps (Listing created → Uploading → Processing → Live): done ones get a check, the current one is
/// filled in the role's colour, the rest are outlined.
Widget stepsBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'steps');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final role = t.accent(configOf(context).navigation.role(n.need('role')).accent);
  final current = scope.lookup(n.need('bind')) as int? ?? 0;
  final rows = n.need<List<StepRow>>('items');
  final done = t.tone(s.name('done_tone'));
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    for (final (i, r) in rows.indexed)
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: s.number('dot'),
            child: Column(children: [
              Container(
                width: s.number('dot'),
                height: s.number('dot'),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i < current ? done.fill : (i == current ? role.fill : s.color('background')),
                  border: Border.all(color: i < current ? done.line : (i == current ? role.line : s.color('border'))),
                ),
                child: i < current
                    ? YamlIcon(s.name('done_icon'), size: s.number('icon'), color: done.onFill)
                    : StyledText('${i + 1}', style: s.name('number'), color: i == current ? role.onFill : t.textMuted),
              ),
              if (i < rows.length - 1)
                Expanded(child: Container(width: s.number('line'), color: s.color('border'))),
            ]),
          ),
          SizedBox(width: s.space('gap')),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: s.space('row_gap')),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StyledText(say(context, r.title), style: s.name('title'), color: i <= current ? t.text : t.textMuted),
                StyledText(say(context, r.note), style: s.name('note'), color: s.color('note_color')),
              ]),
            ),
          ),
        ]),
      ),
  ]);
}
