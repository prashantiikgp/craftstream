/// Builders for the browsing bricks in bricks.yml: search_field, chip_row, results_bar, product_grid, load_more.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/ui/bricks_engine.dart';
import '../screens/screen_scope.dart';
import '../theme/app_theme.dart';
import 'kit.dart';

Widget searchFieldBrick(BuildContext context, BrickNode n) => _SearchField(n);

class _SearchField extends StatefulWidget {
  final BrickNode n;
  const _SearchField(this.n);

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String? _external;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send(String value) => BrickScope.of(context).act(context, widget.n.prop<ActionSpec>('action'), value);

  void _changed(String value) {
    _debounce?.cancel();
    final ms = BrickScope.of(context).lookup(widget.n.need('debounce')) as num? ?? 0;
    _debounce = Timer(Duration(milliseconds: ms.toInt()), () {
      if (mounted) _send(value);
    });
    setState(() {}); // show or hide the clear button
  }

  void _submit(String value) {
    _debounce?.cancel();
    _send(value);
  }

  @override
  Widget build(BuildContext context) {
    // Follow changes made elsewhere (Clear filters, a tag from a product page).
    final current = '${BrickScope.of(context).lookup(widget.n.need('bind')) ?? ''}';
    if (current != _external) {
      _external = current;
      if (_text.text != current) _text.text = current;
    }
    final s = BrickStyle.of(context, 'search_field');
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(s.radius('radius')),
          borderSide: BorderSide(color: c, width: context.tokens.focusRingWidth / 2),
        );
    return SizedBox(
      height: s.number('height'),
      child: TextField(
        controller: _text,
        focusNode: _focus,
        onChanged: _changed,
        onSubmitted: _submit,
        textInputAction: TextInputAction.search,
        style: s.text('text'),
        decoration: InputDecoration(
          hintText: say(context, widget.n.need('hint')),
          hintStyle: s.text('text').copyWith(color: s.color('hint')),
          filled: true,
          fillColor: s.color('background'),
          contentPadding: EdgeInsets.symmetric(horizontal: s.space('padding')),
          border: border(s.color('border')),
          enabledBorder: border(s.color('border')),
          focusedBorder: border(s.color('focus')),
          prefixIcon: Center(
            child: YamlIcon(s.name('search_icon'), size: s.number('icon'), color: s.color('icon_color')),
          ),
          prefixIconConstraints: BoxConstraints.tight(Size(s.number('icon') + 2 * s.space('padding'), s.number('height'))),
          suffixIcon: _text.text.isEmpty
              ? null
              : IconButton(
                  tooltip: say(context, widget.n.need('clear')),
                  icon: YamlIcon(s.name('clear_icon'), size: s.number('icon'), color: s.color('icon_color')),
                  onPressed: () {
                    _text.clear();
                    _submit('');
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }
}

Widget chipRowBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'chip_row');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final tone = t.tone(s.name('tone'));
  final chips = scope.lookup(n.need('bind'));
  Widget chip(String label, bool selected, Object? item) => scope.withItem(
        item,
        0,
        Builder(
          builder: (context) => Pressable(
            accent: tone.fill,
            semanticLabel: label,
            onTap: () => BrickScope.of(context).act(context, n.prop<ActionSpec>('action')),
            builder: (context, active) => Container(
              height: s.number('height'),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: s.space('padding')),
              decoration: BoxDecoration(
                color: selected ? tone.fill : s.color('background'),
                border: Border.all(color: selected || active ? tone.line : s.color('border')),
                borderRadius: BorderRadius.circular(s.radius('radius')),
              ),
              child: StyledText(label, style: s.name('label'), color: selected ? tone.onFill : t.text),
            ),
          ),
        ),
      );
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [
      chip(say(context, n.need('all')), truthy(scope.lookup(n.need('all_selected'))), const {'value': null}),
      for (final c in chips is List ? chips : const []) ...[
        SizedBox(width: s.space('gap')),
        chip('${(c as Map)['label'] ?? c['value']}', c['selected'] == true, c),
      ],
    ]),
  );
}

Widget resultsBarBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'results_bar');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final strings = configOf(context).strings;
  final info = scope.lookup(n.need('bind'));
  final m = info is Map ? info : const {};
  final count = m['count'] as int? ?? 0;
  final text = m['loading'] == true
      ? say(context, n.need('searching'))
      : count == 1
          ? say(context, n.need('one'))
          : strings.get(m['has_more'] == true ? n.need('more') : n.need('many'), {'count': count});
  final tag = m['tag'];
  final sorts = scope.lookup(n.need('sorts'));
  final options = [for (final o in sorts is List ? sorts : const []) o as Map];
  final current = options.where((o) => o['selected'] == true).firstOrNull;
  return Row(children: [
    Expanded(
      child: Wrap(spacing: s.space('gap'), crossAxisAlignment: WrapCrossAlignment.center, children: [
        StyledText(text, style: s.name('count'), color: s.color('count_color')),
        if (tag != null)
          Text(strings.get(n.need('tag'), {'tag': tag}),
              style: context.type.named(s.name('tag_style')).copyWith(color: t.tone(s.name('tag_tone')).ink)),
      ]),
    ),
    PopupMenuButton<String>(
      tooltip: say(context, n.need('sort_label')),
      initialValue: current?['value'] as String?,
      onSelected: (v) => scope.act(context, n.prop<ActionSpec>('action'), v),
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(value: '${o['value']}', child: Text(strings.get('${o['label']}'), style: s.text('menu_style'))),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: s.space('gap')),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          YamlIcon(s.name('sort_icon'), size: s.number('sort_icon_size'), color: s.color('sort_color')),
          SizedBox(width: s.space('gap')),
          StyledText(current == null ? say(context, n.need('sort_label')) : strings.get('${current['label']}'),
              style: s.name('sort_style'), color: s.color('sort_color')),
        ]),
      ),
    ),
  ]);
}

Widget productGridBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'product_grid');
  final scope = BrickScope.of(context);
  final layout = configOf(context).layout;
  final loading = truthy(scope.lookup(n.need('loading')));
  final items = scope.lookup(n.need('bind'));
  return LayoutBuilder(builder: (context, box) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = layout.gridColumns(width);
    final gutter = layout.sizeClassFor(width).gutter;
    final aspect = layout.rules.productCard.aspectRatio;
    final cards = <Widget>[
      if (loading)
        for (var i = 0; i < columns * s.number('skeleton_rows'); i++) _skeleton(context, s, aspect)
      else
        for (final (i, p) in (items is List ? items : const []).indexed)
          scope.withItem(p, i, Builder(builder: (context) => _card(context, n, s, aspect))),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var r = 0; r < cards.length; r += columns) ...[
        if (r > 0) SizedBox(height: gutter),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) SizedBox(width: gutter),
              Expanded(child: r + c < cards.length ? cards[r + c] : const SizedBox.shrink()),
            ],
          ]),
        ),
      ],
    ]);
  });
}

/// A loading placeholder's soft pulse: fades between theme.yml `motion.skeleton_min_opacity` and full, one way
/// every `motion.skeleton_pulse_ms`. Still under reduced motion.
class SkeletonPulse extends StatefulWidget {
  final Widget child;
  const SkeletonPulse({super.key, required this.child});

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _c?.dispose();
      _c = null;
    } else {
      _c ??= AnimationController(vsync: this, duration: context.tokens.skeletonPulse)..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    final from = context.tokens.skeletonMinOpacity;
    return FadeTransition(opacity: Tween(begin: from, end: 1.0).animate(c), child: widget.child);
  }
}

Widget _skeleton(BuildContext context, BrickStyle s, double aspect) =>
    SkeletonPulse(child: _skeletonCard(context, s, aspect));

Widget _skeletonCard(BuildContext context, BrickStyle s, double aspect) => Container(
      decoration: BoxDecoration(color: s.color('background'), border: Border.all(color: s.color('border'))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(aspectRatio: aspect, child: ColoredBox(color: s.color('skeleton'))),
        Padding(
          padding: EdgeInsets.all(s.space('padding')),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final style in [s.name('title'), s.name('artisan'), s.name('price')]) ...[
              Container(
                height: context.type.named(style).fontSize,
                color: s.color('skeleton'),
                margin: EdgeInsets.only(bottom: s.space('padding')),
              ),
            ],
          ]),
        ),
      ]),
    );

Widget _card(BuildContext context, BrickNode n, BrickStyle s, double aspect) {
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final p = scope.item;
  if (p is! Map) return const SizedBox.shrink();
  final brand = t.tone('brand');
  final title = '${p['title'] ?? ''}', artisan = '${p['artisan_name'] ?? ''}';
  final price = configOf(context).format.money(p['price'] as num? ?? 0, '${p['currency']}');
  return Pressable(
    accent: brand.fill,
    semanticLabel: '$title, $artisan, $price',
    onTap: () => scope.act(context, n.prop<ActionSpec>('action')),
    builder: (context, active) => Container(
      decoration: BoxDecoration(
        color: s.color('background'),
        border: Border.all(color: active ? brand.line : s.color('border')),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: aspect,
          child: Stack(fit: StackFit.expand, children: [
            Poster(seed: '${p['id']}', thumbnailUrl: p['thumbnail_url'] as String?),
            Positioned(
              left: s.space('tag_inset'),
              bottom: s.space('tag_inset'),
              child: Container(
                color: s.color('tag_background'),
                padding: EdgeInsets.symmetric(horizontal: t.space.xs + t.space.xxs, vertical: t.space.xxs),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  YamlIcon(s.name('tag_icon'), size: s.number('tag_icon_size'), color: s.color('tag_color')),
                  SizedBox(width: t.space.xs),
                  StyledText(say(context, n.need('video_tag')), style: s.name('tag'), color: s.color('tag_color')),
                ]),
              ),
            ),
          ]),
        ),
        Padding(
          padding: EdgeInsets.all(s.space('padding')),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StyledText(title, style: s.name('title'), maxLines: s.number('title_lines').toInt()),
            SizedBox(height: s.space('gap')),
            StyledText(artisan, style: s.name('artisan'), color: s.color('artisan_color'), maxLines: 1),
            SizedBox(height: s.space('gap')),
            StyledText(price, style: s.name('price'), color: s.color('price_color')),
          ]),
        ),
      ]),
    ),
  );
}

Widget loadMoreBrick(BuildContext context, BrickNode n) {
  final s = BrickStyle.of(context, 'load_more');
  final scope = BrickScope.of(context);
  final t = context.tokens;
  final info = scope.lookup(n.need('bind'));
  final m = info is Map ? info : const {};
  final failed = m['failed'] == true, loading = m['loading'] == true;
  final brand = t.tone('brand');
  final label = say(context, failed ? n.need('retry') : n.need('label'));
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (failed) ...[
      StyledText(say(context, n.need('error')), style: s.name('error'), color: s.color('error_color'), align: TextAlign.center),
      SizedBox(height: s.space('gap')),
    ],
    Pressable(
      accent: brand.fill,
      semanticLabel: label,
      onTap: loading ? null : () => scope.act(context, n.prop<ActionSpec>('action')),
      builder: (context, active) => Container(
        height: s.number('height'),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: s.color('background'),
          border: Border.all(color: active ? brand.line : s.color('border')),
        ),
        child: loading
            ? SizedBox.square(
                dimension: s.number('spinner'),
                child: CircularProgressIndicator(strokeWidth: s.number('spinner_stroke'), color: brand.fill),
              )
            : StyledText(label, style: s.name('label')),
      ),
    ),
  ]);
}
