/// /catalog (DEV_TOOLS only): every token and component, live. Switch palette and light/dark at the top;
/// the readability panel re-checks contrast for whatever is on screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../domain/ui/theme_engine.dart';
import '../../shared/widgets/ds.dart';

class DesignCatalogScreen extends ConsumerWidget {
  const DesignCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
        title: const Text('Design system'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: t.space.lg),
            child: Center(child: StatusBadge('env: ${config.env.name.name}', tone: Tone.info, dot: true)),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, box) {
        final layout = config.layout;
        final sc = layout.sizeClassFor(box.maxWidth);
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.rules.maxContentWidth),
              child: Padding(
                padding: EdgeInsets.all(sc.pagePadding),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const _ThemeSwitcher(),
                  SizedBox(height: t.space.lg),
                  const _Readability(),
                  _gap(t),
                  const _Brand(),
                  _gap(t),
                  const _Colors(),
                  _gap(t),
                  const _Typography(),
                  _gap(t),
                  const _Shape(),
                  _gap(t),
                  const _Components(),
                  _gap(t),
                  _LayoutInfo(width: box.maxWidth),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }

  static Widget _gap(DesignTokens t) => SizedBox(height: t.space.xxxl);
}

class _ThemeSwitcher extends ConsumerWidget {
  const _ThemeSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final engine = ref.watch(appConfigProvider).theme;
    final choice = ref.watch(themeChoiceProvider);
    final controller = ref.read(themeChoiceProvider.notifier);
    return AppCard(
      variant: CardVariant.elevated,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Palette', style: context.type.label),
        SizedBox(height: t.space.sm),
        Wrap(spacing: t.space.sm, runSpacing: t.space.sm, children: [
          for (final name in engine.paletteNames)
            TagChip(engine.labelOf(name), selected: name == choice.palette, onSelected: (_) => controller.setPalette(name)),
        ]),
        SizedBox(height: t.space.lg),
        Text('Mode', style: context.type.label),
        SizedBox(height: t.space.sm),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
            ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
          ],
          selected: {choice.mode},
          onSelectionChanged: (s) => controller.setMode(s.first),
        ),
        SizedBox(height: t.space.md),
        Text('Edit assets/config/ui/theme.yml and hot-restart to try new colours. '
            'Production builds start on THEME_PALETTE from env/prod.json and hide this page.',
            style: context.type.caption.copyWith(color: t.sub)),
      ]),
    );
  }
}

class _Readability extends StatelessWidget {
  const _Readability();

  @override
  Widget build(BuildContext context) {
    final failures = ThemeEngine.checkContrast(context.tokens);
    if (failures.isEmpty) {
      return Notice(
        tone: Tone.success,
        title: 'All ${contrastRules.length + 4} readability checks pass',
        message: 'Text on every surface meets WCAG AA for this palette and mode.',
      );
    }
    return Notice(
      tone: Tone.danger,
      title: '${failures.length} readability problem${failures.length == 1 ? '' : 's'}',
      message: failures.map((f) => '${f.rule.fg} on ${f.rule.bg}: ${f.actual.toStringAsFixed(2)}:1 '
          '(needs ${f.rule.min}:1, ${f.rule.why})').join('\n'),
    );
  }
}

class _Colors extends StatelessWidget {
  const _Colors();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final named = t.namedColors;
    Widget group(String title, List<String> names) => Padding(
          padding: EdgeInsets.only(bottom: t.space.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.type.title),
            SizedBox(height: t.space.sm),
            Wrap(spacing: t.space.md, runSpacing: t.space.md, children: [
              for (final n in names) _Swatch(name: n, color: named[n]!),
            ]),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('Colour', subtitle: '${t.paletteLabel} · ${t.brightness.name}'),
      group('Brand', ['brand', 'brand_d', 'brand_dd', 'brand_ink', 'brand_l', 'brand_ll', 'brand_line', 'on_brand']),
      group('Secondary', ['secondary', 'secondary_ink', 'secondary_l', 'on_secondary']),
      group('Surfaces and text', ['bg', 'card', 'surface_soft', 'hair', 'hair_soft', 'ink', 'sub', 'faint', 'scrim']),
      Text('Status', style: context.type.title),
      SizedBox(height: t.space.sm),
      Wrap(spacing: t.space.md, runSpacing: t.space.md, children: [
        for (final (name, s) in [('success', t.success), ('danger', t.danger), ('info', t.info), ('warning', t.warning)])
          Container(
            width: 220,
            padding: EdgeInsets.all(t.space.md),
            decoration: BoxDecoration(
              color: s.wash,
              border: Border.all(color: s.border),
              borderRadius: BorderRadius.circular(t.radius.sm),
            ),
            child: Row(children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: s.fill, shape: BoxShape.circle)),
              SizedBox(width: t.space.sm),
              Expanded(child: Text('$name text on wash', style: context.type.label.copyWith(color: s.ink))),
              Text('${contrastRatio(s.ink, s.wash).toStringAsFixed(1)}:1',
                  style: context.type.caption.copyWith(color: s.ink)),
            ]),
          ),
      ]),
    ]);
  }
}

class _Swatch extends StatelessWidget {
  final String name;
  final Color color;
  const _Swatch({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final onBg = contrastRatio(color, t.bg);
    return Container(
      width: 132,
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.hair),
        borderRadius: BorderRadius.circular(t.radius.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 56, color: color),
        Padding(
          padding: EdgeInsets.all(t.space.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: context.type.caption.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
            Text(hexOf(color), style: context.type.caption.copyWith(color: t.sub)),
            Text('${onBg.toStringAsFixed(1)}:1 on bg', style: context.type.caption.copyWith(color: t.sub)),
          ]),
        ),
      ]),
    );
  }
}

class _Typography extends StatelessWidget {
  const _Typography();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ty = context.type;
    final rows = <(String, TextStyle, String)>[
      ('display', ty.display, 'Made by hand, shown in full'),
      ('h1', ty.h1, 'Hand-thrown clay mug'),
      ('h2', ty.h2, 'Watch how it was made'),
      ('h3', ty.h3, 'From the same artisan'),
      ('title', ty.title, 'Meera · Khurja, Uttar Pradesh'),
      ('body', ty.body, 'Wheel-thrown, glazed by hand and fired twice. Each piece is a little different.'),
      ('body_strong', ty.bodyStrong, 'Ships in 3–5 days'),
      ('label', ty.label, 'Add to order'),
      ('caption', ty.caption, '12 min process video · 144p on slow networks'),
      ('price', ty.price, formatMoney(120000, 'INR')),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Type', subtitle: 'Poppins for headings, Inter for text. Bundled, Latin + ₹ only.'),
      for (final (name, style, sample) in rows)
        Padding(
          padding: EdgeInsets.only(bottom: t.space.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            SizedBox(
              width: 120,
              child: Text('$name\n${style.fontFamily} ${style.fontSize!.toInt()}/${style.fontWeight!.value}',
                  style: ty.caption.copyWith(color: t.sub)),
            ),
            Expanded(child: Text(sample, style: style)),
          ]),
        ),
    ]);
  }
}

class _Shape extends StatelessWidget {
  const _Shape();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final space = {
      'xxs': t.space.xxs, 'xs': t.space.xs, 'sm': t.space.sm, 'md': t.space.md, 'lg': t.space.lg,
      'xl': t.space.xl, 'xxl': t.space.xxl, 'xxxl': t.space.xxxl, 'section': t.space.section,
    };
    final radius = {'tag': t.radius.tag, 'sm': t.radius.sm, 'md': t.radius.md, 'lg': t.radius.lg};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Space, shape and depth'),
      for (final MapEntry(:key, :value) in space.entries)
        Padding(
          padding: EdgeInsets.only(bottom: t.space.xs),
          child: Row(children: [
            SizedBox(width: 90, child: Text('$key ${value.toInt()}', style: context.type.caption.copyWith(color: t.sub))),
            Container(width: value * 3, height: 10, decoration: BoxDecoration(color: t.brandL, borderRadius: BorderRadius.circular(2))),
          ]),
        ),
      SizedBox(height: t.space.lg),
      Wrap(spacing: t.space.lg, runSpacing: t.space.lg, children: [
        for (final MapEntry(:key, :value) in radius.entries)
          Container(
            width: 96,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.brandLine),
              borderRadius: BorderRadius.circular(value),
            ),
            child: Text('radius $key\n${value.toInt()}', textAlign: TextAlign.center, style: context.type.caption),
          ),
        for (final (name, shadow) in [('shadow sm', t.shadowSm), ('shadow lg', t.shadowLg)])
          Container(
            width: 140,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(t.radius.md),
              boxShadow: boxShadows(shadow),
            ),
            child: Text(name, style: context.type.caption),
          ),
      ]),
    ]);
  }
}

class _Components extends StatefulWidget {
  const _Components();

  @override
  State<_Components> createState() => _ComponentsState();
}

class _ComponentsState extends State<_Components> {
  final _selected = <String>{'pottery'};

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget row(List<Widget> children) =>
        Wrap(spacing: t.space.md, runSpacing: t.space.md, crossAxisAlignment: WrapCrossAlignment.center, children: children);
    Widget label(String s) => Padding(
          padding: EdgeInsets.only(top: t.space.xl, bottom: t.space.sm),
          child: Text(s, style: context.type.title),
        );
    void noop() {}
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Components'),
      label('Buttons'),
      row([
        AppButton('Place order', onPressed: noop, icon: Icons.shopping_bag_outlined),
        AppButton('Watch process', onPressed: noop, variant: ButtonVariant.secondary, icon: Icons.play_arrow_rounded),
        AppButton('See all', onPressed: noop, variant: ButtonVariant.ghost),
        AppButton('Remove', onPressed: noop, variant: ButtonVariant.danger),
      ]),
      SizedBox(height: t.space.md),
      row([
        AppButton('Small', onPressed: noop, size: ButtonSize.sm),
        AppButton('Large', onPressed: noop, size: ButtonSize.lg),
        const AppButton('Disabled', onPressed: null),
        AppButton('Uploading', onPressed: noop, loading: true),
      ]),
      label('Badges'),
      row([
        const StatusBadge('Live', tone: Tone.success, dot: true),
        const StatusBadge('Processing', tone: Tone.warning, dot: true),
        const StatusBadge('Failed', tone: Tone.danger),
        const StatusBadge('144p ready', tone: Tone.info),
        const StatusBadge('Handmade', tone: Tone.brand),
        const StatusBadge('Pottery', tone: Tone.secondary),
        const StatusBadge('Draft', tone: Tone.neutral),
      ]),
      label('Filter chips'),
      row([
        for (final tag in ['pottery', 'textiles', 'woodwork', 'brass', 'jewellery'])
          TagChip(tag, selected: _selected.contains(tag), onSelected: (on) {
            setState(() => on ? _selected.add(tag) : _selected.remove(tag));
          }),
      ]),
      label('Inputs'),
      Wrap(spacing: t.space.lg, runSpacing: t.space.lg, children: const [
        SizedBox(width: 300, child: AppTextField(label: 'Title', hint: 'e.g. Hand-thrown clay mug')),
        SizedBox(width: 300, child: AppTextField(label: 'Price (₹)', hint: '450', helper: 'Before taxes')),
        SizedBox(width: 300, child: AppTextField(label: 'Your name', error: 'Please enter at least 2 letters')),
      ]),
      label('Notices'),
      const Notice(tone: Tone.info, title: 'Your video is processing', message: 'This takes a few minutes. You can close the app.'),
      SizedBox(height: t.space.sm),
      const Notice(tone: Tone.success, title: 'Order placed', message: 'Meera will be in touch about delivery.'),
      SizedBox(height: t.space.sm),
      const Notice(tone: Tone.warning, title: 'Slow connection', message: 'Playing the 144p version so it never stops.'),
      SizedBox(height: t.space.sm),
      const Notice(tone: Tone.danger, title: 'Upload paused', message: 'We lost the network. It resumes where it stopped.'),
      label('Prices'),
      row([
        const PriceText(450),
        const PriceText(120000),
        const PriceText(499.5),
        PriceText(1234.5, currency: 'USD', style: context.type.title),
      ]),
      label('Cards'),
      Wrap(spacing: t.space.lg, runSpacing: t.space.lg, children: [
        for (final v in CardVariant.values)
          SizedBox(
            width: 220,
            child: AppCard(
              variant: v,
              onTap: v == CardVariant.interactive ? noop : null,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    decoration: BoxDecoration(color: t.brandLl, borderRadius: BorderRadius.circular(t.radius.sm)),
                    child: Icon(Icons.play_circle_outline, color: t.brandInk, size: 36),
                  ),
                ),
                SizedBox(height: t.space.sm),
                Text('Card: ${v.name}', style: context.type.title),
                Text('Meera · pottery', style: context.type.caption.copyWith(color: t.sub)),
                SizedBox(height: t.space.xs),
                const PriceText(450),
              ]),
            ),
          ),
      ]),
      label('Empty and loading'),
      Wrap(spacing: t.space.lg, runSpacing: t.space.lg, children: [
        SizedBox(
          width: 320,
          child: AppCard(
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Nothing matches yet',
              message: 'Try a shorter word, or clear the tag filter.',
              action: AppButton('Clear filters', onPressed: noop, variant: ButtonVariant.secondary, size: ButtonSize.sm),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const AspectRatio(aspectRatio: 4 / 3, child: Skeleton(height: double.infinity)),
              SizedBox(height: t.space.sm),
              const Skeleton(height: 14, width: 150),
              SizedBox(height: t.space.xs),
              const Skeleton(height: 12, width: 90),
            ]),
          ),
        ),
      ]),
    ]);
  }
}

class _LayoutInfo extends ConsumerWidget {
  final double width;
  const _LayoutInfo({required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final layout = ref.watch(appConfigProvider).layout;
    final sc = layout.sizeClassFor(width);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Layout', subtitle: 'From assets/config/ui/layout.yml. Resize the window to see it change.'),
      Wrap(spacing: t.space.sm, runSpacing: t.space.sm, children: [
        StatusBadge('width ${width.toInt()} px', tone: Tone.neutral),
        StatusBadge('class: ${sc.name}', tone: Tone.brand),
        StatusBadge('${layout.gridColumns(width)} columns', tone: Tone.info),
        StatusBadge('nav: ${sc.navigation.name}', tone: Tone.secondary),
        StatusBadge('product: ${sc.productLayout.name}', tone: Tone.secondary),
      ]),
    ]);
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final caption = context.type.caption.copyWith(color: t.sub);
    Widget labelled(String label, Widget child) => Column(mainAxisSize: MainAxisSize.min, children: [
          child,
          SizedBox(height: t.space.xs),
          Text(label, style: caption),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Brand',
          subtitle: 'A thrown vessel with a play button in its belly. Drawn in code from the palette (lib/shared/brand/).'),
      const BrandLockup(height: 44),
      SizedBox(height: t.space.lg),
      Wrap(spacing: t.space.xl, runSpacing: t.space.lg, crossAxisAlignment: WrapCrossAlignment.end, children: [
        for (final size in [16.0, 24.0, 32.0, 48.0, 96.0]) labelled('${size.toInt()} px', BrandMark(size: size)),
        labelled('ink', const BrandMark(size: 48, tone: MarkTone.ink)),
        labelled(
          'on brand',
          Container(
            padding: EdgeInsets.all(t.space.sm),
            decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(t.radius.md)),
            child: const BrandMark(size: 48, tone: MarkTone.onBrand),
          ),
        ),
      ]),
      SizedBox(height: t.space.xl),
      Text('Illustrations', style: context.type.title),
      SizedBox(height: t.space.md),
      Wrap(spacing: t.space.lg, runSpacing: t.space.lg, children: [
        for (final (kind, label) in const [
          (SpotKind.emptySearch, 'Nothing matches'),
          (SpotKind.processing, 'Uploading / processing'),
          (SpotKind.orderPlaced, 'Order placed'),
          (SpotKind.slowNetwork, 'Slow network'),
        ])
          AppCard(child: labelled(label, SpotIllustration(kind, width: 180))),
      ]),
      SizedBox(height: t.space.xl),
      Text('Poster placeholders', style: context.type.title),
      SizedBox(height: t.space.md),
      Wrap(spacing: t.space.lg, runSpacing: t.space.lg, children: [
        for (final tag in ['pottery', 'textiles', 'woodwork', 'brass', 'jewellery', 'kantha'])
          SizedBox(
            width: 220,
            child: labelled(tag,
                ProductPosterPlaceholder(tag: tag, borderRadius: BorderRadius.circular(t.radius.md))),
          ),
      ]),
    ]);
  }
}
