/// One builder per brick in assets/config/ui/bricks.yml. A builder reads its props from the [BrickNode] (already
/// checked against the catalogue at startup) and its look from the brick's `style:` block; it holds no sizes,
/// colours, text, icons or routes of its own.
library;

import 'package:flutter/material.dart';

import '../../domain/ui/bricks_engine.dart';
import '../../schemas/app/navigation_schema.dart';
import '../format/money.dart';
import '../screens/screen_scope.dart';
import '../theme/app_theme.dart';
import 'browse_bricks.dart';
import 'burst_brick.dart';
import 'form_bricks.dart';
import 'kit.dart';
import 'product_bricks.dart';
import 'sell_bricks.dart';

typedef BrickBuild = Widget Function(BuildContext context, BrickNode node);

class BrickBuilder {
  final BrickBuild build;

  /// Takes a share of the screen height in `fill: true` screens.
  final bool flexes;
  const BrickBuilder(this.build, {this.flexes = false});
}

/// Every brick bricks.yml defines; screen_render_test fails if one is missing here.
const brickBuilders = <String, BrickBuilder>{
  'text': BrickBuilder(_text),
  'wordmark': BrickBuilder(_wordmark),
  'theme_toggle': BrickBuilder(_themeToggle),
  'doors': BrickBuilder(_doors, flexes: true),
  'door': BrickBuilder(_door),
  'link_row': BrickBuilder(_linkRow),
  'top_bar': BrickBuilder(_topBar),
  'mark': BrickBuilder(_mark),
  'receipt': BrickBuilder(_receipt),
  'button': BrickBuilder(_button),
  'list': BrickBuilder(_list),
  'order_card': BrickBuilder(_orderCard),
  'empty_state': BrickBuilder(_emptyState),
  'search_field': BrickBuilder(searchFieldBrick),
  'chip_row': BrickBuilder(chipRowBrick),
  'results_bar': BrickBuilder(resultsBarBrick),
  'product_grid': BrickBuilder(productGridBrick),
  'load_more': BrickBuilder(loadMoreBrick),
  'split': BrickBuilder(splitBrick),
  'value': BrickBuilder(valueBrick),
  'tag_row': BrickBuilder(tagRowBrick),
  'artisan_row': BrickBuilder(artisanRowBrick),
  'notice': BrickBuilder(noticeBrick),
  'buy_bar': BrickBuilder(buyBarBrick),
  'video_player': BrickBuilder(videoPlayerBrick),
  'product_summary': BrickBuilder(productSummaryBrick),
  'text_field': BrickBuilder(textFieldBrick),
  'stepper': BrickBuilder(stepperBrick),
  'amount_row': BrickBuilder(amountRowBrick),
  'listing_card': BrickBuilder(listingCardBrick),
  'tag_picker': BrickBuilder(tagPickerBrick),
  'video_pick': BrickBuilder(videoPickBrick),
  'progress_bar': BrickBuilder(progressBarBrick),
  'steps': BrickBuilder(stepsBrick),
  'crumb': BrickBuilder(_crumb),
  'burst': BrickBuilder(burstBrick),
  'spacer': BrickBuilder(_spacer, flexes: true),
};

Widget buildBrick(BuildContext context, BrickNode node) {
  final b = brickBuilders[node.brick] ?? (throw StateError('${node.where}: no builder for brick "${node.brick}"'));
  return BrickScope.of(context).shows(node) ? b.build(context, node) : const SizedBox.shrink();
}

bool brickFlexes(BrickNode node) => brickBuilders[node.brick]?.flexes ?? false;

String _say(BuildContext context, BrickNode n, String prop) => say(context, n.need<String>(prop));

void _act(BuildContext context, BrickNode n) => BrickScope.of(context).act(context, n.prop<ActionSpec>('action'));

Widget _text(BuildContext context, BrickNode n) {
  final text = say(context, n.need('text'), args: n.prop('args'), fallback: n.prop('fallback'));
  return StyledText(
    text,
    style: n.need('style'),
    color: context.tokens.color(n.need('color')),
    align: switch (n.need<String>('align')) {
      'center' => TextAlign.center,
      'end' => TextAlign.end,
      _ => TextAlign.start,
    },
  );
}

Widget _wordmark(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'wordmark');
  final lg = n.need<String>('size') == 'lg';
  // On phones the large wordmark sits in one row (stripes beside the name) so Home fits one screen.
  final compact = lg && s.names('compact_on').contains(BrickScope.of(context).sizeClass);
  final name = StyledText(
    configOf(context).strings.get('brand.name'),
    style: s.name(compact ? 'compact_name' : (lg ? 'lg_name' : 'sm_name')),
  );
  final mark = Stripes(
    size: s.number(compact ? 'compact_mark' : (lg ? 'lg_mark' : 'sm_mark')),
    accents: s.names('stripes'),
  );
  final tagline = n.prop<String>('tagline');
  if (!lg || compact) {
    final row = Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        mark,
        SizedBox(width: s.space('gap')),
        name,
      ],
    );
    if (!compact || tagline == null) return row;
    return Column(
      children: [
        row,
        SizedBox(height: s.space('gap')),
        StyledText(say(context, tagline), style: s.name('tagline'), color: s.color('tagline_color')),
      ],
    );
  }
  return Column(
    children: [
      mark,
      SizedBox(height: s.space('gap')),
      name,
      if (tagline != null) ...[
        SizedBox(height: s.space('gap')),
        StyledText(say(context, tagline), style: s.name('tagline'), color: s.color('tagline_color')),
      ],
    ],
  );
}

Widget _themeToggle(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'theme_toggle');
  final t = context.tokens;
  final brand = t.tone('brand');
  final strings = configOf(context).strings;
  return Align(
    alignment: n.need<String>('align') == 'start' ? Alignment.centerLeft : Alignment.centerRight,
    child: Pressable(
      accent: brand.fill,
      semanticLabel: strings.get(t.isDark ? 'theme.to_light' : 'theme.to_dark'),
      onTap: () => BrickScope.of(context).act(context, const ToggleThemeAction()),
      builder: (context, active) => Container(
        width: s.number('box'),
        height: s.number('box'),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: s.color('background'),
          border: Border.all(color: active ? brand.line : s.color('border')),
          borderRadius: BorderRadius.circular(s.radius('radius')),
        ),
        child: YamlIcon(s.name(t.isDark ? 'icon_in_dark' : 'icon_in_light'), size: s.number('icon'), color: t.text),
      ),
    ),
  );
}

Widget _doors(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'doors');
  final layout = configOf(context).layout;
  final classes = layout.sizeClassNames;
  final current = classes.indexOf(layout.sizeClassFor(MediaQuery.sizeOf(context).width).name);
  final sideBySide = current >= classes.indexOf(s.name('side_by_side_from'));
  final share = BrickScope.of(context).fill || sideBySide;
  final gap = s.space('gap');
  final doors = n.need<List<BrickNode>>('items');
  final children = [
    for (final (i, d) in doors.indexed) ...[
      if (i > 0) SizedBox(width: sideBySide ? gap : null, height: sideBySide ? null : gap),
      share ? Expanded(child: buildBrick(context, d)) : buildBrick(context, d),
    ],
  ];
  final group = sideBySide
      ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  if (!share) return group;
  // Sharing the page's height: never taller than max_height, so the doors stay a sensible size on big screens.
  return ConstrainedBox(
    constraints: BoxConstraints(maxHeight: s.number(sideBySide ? 'max_height' : 'stacked_max_height')),
    child: sideBySide && !BrickScope.of(context).fill ? IntrinsicHeight(child: group) : group,
  );
}

Widget _door(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'door');
  final t = context.tokens;
  final config = configOf(context);
  final roleName = n.need<String>('role');
  final role = config.navigation.role(roleName);
  final accent = t.accent(role.accent);
  final tag = config.strings.get('nav.role_tag', {'number': role.number, 'label': config.strings.get(role.label)});
  final title = _say(context, n, 'title');
  final body = n.prop<String>('body');
  final radius = BorderRadius.circular(s.radius('radius'));
  final compact = s.names('compact_on').contains(BrickScope.of(context).sizeClass);
  return Pressable(
    accent: accent.fill,
    lift: t.doorHoverLift,
    semanticLabel: body == null ? title : '$title. ${say(context, body)}',
    onTap: () => _act(context, n),
    builder: (context, active) => Container(
      constraints: BoxConstraints(minHeight: s.number('min_height')),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: s.color('background'),
        border: Border.all(color: active ? accent.line : s.color('border')),
        borderRadius: radius,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: ArtShapes(config.art.door(n.prop<String>('art') ?? roleName))),
          Padding(
            padding: EdgeInsets.all(s.space(compact ? 'compact_padding' : 'padding')),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StyledText(tag, style: s.name('number'), color: accent.ink),
                    ),
                    Container(
                      width: s.number('arrow_box'),
                      height: s.number('arrow_box'),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border.all(color: accent.line)),
                      child: YamlIcon(s.name('arrow'), size: s.number('arrow_icon'), color: accent.ink),
                    ),
                  ],
                ),
                SizedBox(height: s.space('gap')),
                StyledText(title, style: s.name(compact ? 'compact_title' : 'title')),
                if (body != null) ...[
                  SizedBox(height: s.space('gap')),
                  // A share of the door's width, so the text scales with the door and stays clear of its art.
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: s.number('body_width'),
                    child: StyledText(
                      say(context, body),
                      style: s.name('body'),
                      color: s.color('body_color'),
                      maxLines: s.number('body_lines').toInt(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _linkRow(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'link_row');
  final tone = context.tokens.tone(n.need('tone'));
  final label = _say(context, n, 'label');
  final countPath = n.prop<String>('count');
  final count = countPath == null ? null : BrickScope.of(context).lookup(countPath);
  return Pressable(
    accent: tone.fill,
    semanticLabel: count == null ? label : '$label, $count',
    onTap: () => _act(context, n),
    builder: (context, active) => Container(
      height: s.number('height'),
      padding: EdgeInsets.symmetric(horizontal: s.space('padding')),
      decoration: BoxDecoration(
        color: s.color('background'),
        border: Border.all(color: active ? tone.line : s.color('border')),
      ),
      child: Row(
        children: [
          YamlIcon(n.need('icon'), size: s.number('icon'), color: tone.ink),
          SizedBox(width: s.space('gap')),
          Expanded(child: StyledText(label, style: s.name('label'))),
          if (count != null)
            StyledText(
              configOf(context).strings.get('common.count_go', {'count': count}),
              style: s.name('count'),
              color: tone.ink,
            ),
        ],
      ),
    ),
  );
}

Widget _topBar(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'top_bar');
  final t = context.tokens;
  final config = configOf(context);
  final brand = t.tone('brand');
  final home = n.need<String>('leading') == 'home';
  final label = n.prop<String>('label');
  final roleName = n.prop<String>('role');
  final role = roleName == null ? null : config.navigation.role(roleName);
  return SizedBox(
    height: s.number('height'),
    child: Row(
      children: [
        Pressable(
          accent: brand.fill,
          semanticLabel: label == null ? config.strings.get('common.back') : say(context, label),
          onTap: () => _act(context, n),
          builder: (context, active) => home
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stripes(size: s.number('mark'), accents: s.names('stripes')),
                    if (label != null) ...[
                      SizedBox(width: s.space('padding')),
                      StyledText(
                        say(context, label),
                        style: s.name('label'),
                        color: active ? t.text : s.color('label_color'),
                      ),
                    ],
                  ],
                )
              : Container(
                  width: s.number('box'),
                  height: s.number('box'),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: active ? brand.line : s.color('border'))),
                  child: YamlIcon(s.name('back_icon'), size: s.number('icon'), color: t.text),
                ),
        ),
        SizedBox(width: s.space('padding')),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _crumbs(context, s, n.prop<List<BrickNode>>('crumbs') ?? const [], role),
          ),
        ),
      ],
    ),
  );
}

/// The trail on the right of the top bar: crumbs joined by the separator. Crumbs with an action lead back (in the
/// role's colour); the last one is where you are. Long crumbs shorten with an ellipsis.
Widget _crumbs(BuildContext context, BrickStyle s, List<BrickNode> crumbs, RoleSchema? role) {
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final shown = crumbs.where(scope.shows).toList();
  final link = role == null ? t.tone('brand').ink : t.accent(role.accent).ink;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, c) in shown.indexed) ...[
        if (i > 0) StyledText(s.name('separator'), style: s.name('crumb'), color: s.color('separator_color')),
        Flexible(
          child: c.prop<ActionSpec>('action') == null
              ? StyledText(crumbText(context, c), style: s.name('crumb'), color: s.color('crumb_current'), maxLines: 1)
              : Pressable(
                  accent: link,
                  semanticLabel: crumbText(context, c),
                  onTap: () => scope.act(context, c.prop<ActionSpec>('action')),
                  builder: (context, active) => StyledText(
                    crumbText(context, c),
                    style: s.name('crumb'),
                    color: active ? t.text : link,
                    maxLines: 1,
                  ),
                ),
        ),
      ],
    ],
  );
}

/// A crumb's words: its role ("01 / BUY"), its strings key, or its data.
String crumbText(BuildContext context, BrickNode c) {
  final config = configOf(context);
  final role = c.prop<String>('role');
  if (role != null) {
    final r = config.navigation.role(role);
    return config.strings.get('nav.role_tag', {'number': r.number, 'label': config.strings.get(r.label)});
  }
  final text = c.prop<String>('text');
  if (text != null) return config.strings.get(text);
  return '${BrickScope.of(context).lookup(c.need('bind')) ?? ''}';
}

/// A crumb on its own (outside a top bar): just its words.
Widget _crumb(BuildContext context, BrickNode n) =>
    StyledText(crumbText(context, n), style: BrickStyle.of(context, 'top_bar').name('crumb'));

Widget _mark(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'mark');
  final tone = context.tokens.tone(n.need('tone'));
  return Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: s.number('box'),
      height: s.number('box'),
      color: tone.fill,
      alignment: Alignment.center,
      child: YamlIcon(n.need('icon'), size: s.number('icon'), color: tone.onFill, strokeWidth: s.number('stroke')),
    ),
  );
}

Widget _receipt(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'receipt');
  final record = BrickScope.of(context).lookup(n.need('bind'));
  if (record is! Map) return const SizedBox.shrink();
  final pad = s.space('padding'), gap = s.space('gap');
  Widget line(String label, Widget value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: StyledText(label, style: s.name('row_label'), color: s.color('row_label_color')),
      ),
      SizedBox(width: gap),
      Flexible(
        flex: 2,
        child: Align(alignment: AlignmentDirectional.centerEnd, child: value),
      ),
    ],
  );
  return Container(
    decoration: BoxDecoration(
      color: s.color('background'),
      border: Border.all(color: s.color('border')),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.all(pad),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StyledText(_say(context, n, 'number'), style: s.name('label'), color: s.color('label_color')),
                    SizedBox(height: gap),
                    SelectableText('${record['id']}', style: s.text('number')),
                  ],
                ),
              ),
              StatusTag(kind: 'order', value: '${record['status']}', style: s.name('tag')),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: s.color('divider')),
        Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            children: [
              for (final r in n.prop<List<ReceiptRow>>('rows') ?? const <ReceiptRow>[]) ...[
                line(
                  say(context, r.label),
                  StyledText('${record[r.field] ?? ''}', style: r.style ?? s.name('row_value'), align: TextAlign.end),
                ),
                SizedBox(height: gap),
              ],
              Divider(height: gap, thickness: 1, color: s.color('divider')),
              line(
                _say(context, n, 'total'),
                StyledText(
                  formatMoney(record['total'] as num? ?? 0, '${record['currency']}'),
                  style: s.name('total_value'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _button(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'button');
  final t = context.tokens;
  final enabledPath = n.prop<String>('enabled'), busyPath = n.prop<String>('busy');
  final busy = busyPath != null && truthy(BrickScope.of(context).lookup(busyPath));
  final enabled = (enabledPath == null || truthy(BrickScope.of(context).lookup(enabledPath))) && !busy;
  final tone = t.tone(enabled ? n.need('tone') : 'neutral');
  final primary = n.need<String>('variant') == 'primary';
  final label = _say(context, n, 'label');
  final icon = n.prop<String>('icon');
  final ink = primary ? tone.onFill : t.text;
  return Pressable(
    accent: tone.fill,
    semanticLabel: label,
    onTap: enabled ? () => _act(context, n) : null,
    builder: (context, active) => Container(
      height: s.number('height'),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? tone.fill : s.color('ghost_background'),
        border: primary ? null : Border.all(color: active ? tone.line : s.color('ghost_border')),
        borderRadius: BorderRadius.circular(s.radius('radius')),
      ),
      child: busy
          ? SizedBox.square(
              dimension: s.number('spinner'),
              child: CircularProgressIndicator(strokeWidth: s.number('spinner_stroke'), color: ink),
            )
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: s.space('padding')),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: StyledText(label, style: s.name('label'), color: ink, maxLines: 1),
                  ),
                  if (icon != null) ...[
                    SizedBox(width: s.space('gap')),
                    YamlIcon(icon, size: s.number('icon'), color: ink),
                  ],
                ],
              ),
            ),
    ),
  );
}

Widget _list(BuildContext context, BrickNode n) {
  final scope = BrickScope.of(context);
  final items = scope.lookup(n.need('bind'));
  final gap = context.tokens.spacing(n.need('gap'));
  final item = n.need<BrickNode>('item');
  final built = [
    for (final (i, entry) in (items is List ? items : const []).indexed)
      scope.withItem(entry, i, Builder(builder: (context) => buildBrick(context, item))),
  ];
  final cards = n.need<String>('layout') == 'cards';
  return LayoutBuilder(
    builder: (context, box) {
      // cards: as many columns as layout.yml list_card fits in the width the list has (1 on phones).
      final columns = cards ? configOf(context).layout.listColumnsIn(box.maxWidth, gap) : 1;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var r = 0; r < built.length; r += columns) ...[
            if (r > 0) SizedBox(height: gap),
            if (columns == 1)
              built[r]
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < columns; c++) ...[
                      if (c > 0) SizedBox(width: gap),
                      Expanded(child: r + c < built.length ? built[r + c] : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
          ],
        ],
      );
    },
  );
}

Widget _orderCard(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'order_card');
  final t = context.tokens;
  final scope = BrickScope.of(context);
  final o = scope.lookup(n.need('bind'));
  if (o is! Map) return const SizedBox.shrink();
  final brand = t.tone('brand');
  final highlight = s.flag('highlight_first') && scope.index == 0;
  final title = '${o['product_title'] ?? ''}';
  final total = formatMoney(o['total'] as num? ?? 0, '${o['currency']}');
  return Pressable(
    accent: brand.fill,
    semanticLabel: '$title, $total',
    onTap: n.prop<ActionSpec>('action') == null ? null : () => _act(context, n),
    builder: (context, active) => Container(
      decoration: BoxDecoration(
        color: s.color('background'),
        border: Border.all(color: highlight || active ? brand.line : s.color('border')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(s.space('padding')),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(dimension: s.number('poster'), child: PosterArt('${o['product_id']}')),
                SizedBox(width: s.space('gap')),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StyledText(title, style: s.name('title'), maxLines: s.number('title_lines').toInt()),
                      StyledText(
                        say(context, n.need('line'), args: n.prop('args')),
                        style: s.name('line_style'),
                        color: s.color('line_color'),
                      ),
                      StyledText(total, style: s.name('total')),
                    ],
                  ),
                ),
                StatusTag(kind: 'order', value: '${o['status']}', style: s.name('tag')),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: s.color('divider')),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: s.space('padding'), vertical: t.space.sm),
            child: StyledText(
              configOf(context).strings.get(n.need('number'), {'id': '${o['id']}'}),
              style: s.name('footer'),
              color: s.color('footer_color'),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _emptyState(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'empty_state');
  final t = context.tokens;
  final message = n.prop<String>('message'), button = n.prop<String>('button');
  final brand = t.tone('brand');
  return Padding(
    padding: EdgeInsets.symmetric(vertical: s.space('padding')),
    child: Column(
      children: [
        Container(
          width: s.number('icon_box'),
          height: s.number('icon_box'),
          color: s.color('icon_background'),
          alignment: Alignment.center,
          child: YamlIcon(n.need('icon'), size: s.number('icon'), color: s.color('icon_color')),
        ),
        SizedBox(height: s.space('gap')),
        StyledText(_say(context, n, 'title'), style: s.name('title'), align: TextAlign.center),
        if (message != null) ...[
          SizedBox(height: s.space('gap')),
          StyledText(
            say(context, message),
            style: s.name('message'),
            color: s.color('message_color'),
            align: TextAlign.center,
          ),
        ],
        if (button != null && n.prop<ActionSpec>('action') != null) ...[
          SizedBox(height: s.space('gap')),
          Pressable(
            accent: brand.fill,
            semanticLabel: say(context, button),
            onTap: () => _act(context, n),
            builder: (context, _) => Container(
              padding: EdgeInsets.symmetric(horizontal: t.space.xl, vertical: t.space.md),
              color: brand.fill,
              child: StyledText(say(context, button), style: s.name('title'), color: brand.onFill),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _spacer(BuildContext context, BrickNode n) => const SizedBox.shrink();
