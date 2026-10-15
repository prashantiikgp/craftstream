/// Draws one screen from ui/screens/<name>.yml: backdrop, top, body (or empty/error), bottom; width and padding
/// from layout.yml; data from the screen's source; actions from the bricks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../domain/ui/bricks_engine.dart';
import '../../domain/ui/screen_engine.dart';
import '../../schemas/ui/screen_schema.dart';
import '../bricks/bricks.dart';
import '../bricks/kit.dart';
import '../theme/app_theme.dart';
import 'screen_scope.dart';
import 'sources.dart';

class ScreenHost extends ConsumerWidget {
  final String name;
  final Map<String, String> params;
  const ScreenHost({super.key, required this.name, this.params = const {}});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final spec = config.screens.screen(name);
    final source = spec.data == null
        ? null
        : screenSources[spec.data] ??
              (throw StateError('${spec.name}.yml: no data source "${spec.data}" in sources.dart'));
    final data = source?.build(ref, params) ?? const ScreenData.ready({});
    final t = context.tokens;

    void run(BuildContext context, ActionSpec action, BrickScope scope, [Object? value]) {
      final router = GoRouter.of(context);
      switch (action) {
        case CallAction(:final name, :final withPath, :final then):
          final call = data.calls[name] ?? (throw StateError('${spec.name}.yml: data source has no call "$name"'));
          final result = call(withPath == null ? value : scope.lookup(withPath));
          if (then == null) return;
          if (result is Future<Object?>) {
            result.then((r) {
              if (r != false && context.mounted) run(context, then, scope.withResult(r));
            }, onError: (_) {});
          } else if (result != false) {
            run(context, then, scope.withResult(result));
          }
        case GoAction(:final template):
          router.go(scope.fillTemplate(template));
        case BackAction():
          router.canPop() ? router.pop() : router.go(config.app.initialRoute);
        case ToggleThemeAction():
          ref.read(themeChoiceProvider.notifier).toggle(MediaQuery.platformBrightnessOf(context));
      }
    }

    final body = switch (data.state) {
      SourceState.ready => spec.body,
      SourceState.empty => spec.empty.isEmpty ? spec.body : spec.empty,
      SourceState.error => spec.error,
      SourceState.loading => const <BrickNode>[],
    };

    return Scaffold(
      backgroundColor: t.ground,
      body: BrickScope(
        values: data.values,
        params: params,
        run: run,
        sizeClass: config.layout.sizeClassFor(MediaQuery.sizeOf(context).width).name,
        child: Stack(
          children: [
            if (spec.backdrop != null) Positioned.fill(child: ArtShapes(config.art.backdrop(spec.backdrop!))),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, box) {
                  final layout = config.layout;
                  final pad = layout.sizeClassFor(box.maxWidth).pagePadding;
                  final wide = switch (spec.width) {
                    ScreenWidth.narrow => false,
                    ScreenWidth.wide => true,
                    ScreenWidth.auto => layout.productSideBySide(box.maxWidth),
                  };
                  final maxWidth = wide ? layout.rules.maxContentWidth : layout.rules.formMaxWidth;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (spec.top.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: pad),
                                child: _Bricks(spec.top, gap: t.spacing(spec.gap), fill: false),
                              ),
                            Expanded(
                              child: data.state == SourceState.loading
                                  ? Center(child: CircularProgressIndicator(color: t.tone('brand').fill))
                                  : _Body(spec, body),
                            ),
                            if (spec.bottom.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: pad),
                                child: _Bricks(spec.bottom, gap: t.spacing(spec.gap), fill: false),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The body: scrolls; in `fill: true` screens it is at least the screen's height, so doors share it (up to their
/// max_height, then the page centres) and a spacer pushes what follows down.
class _Body extends StatelessWidget {
  final ScreenSpec spec;
  final List<BrickNode> nodes;
  const _Body(this.spec, this.nodes);

  @override
  Widget build(BuildContext context) {
    final gap = context.tokens.spacing(spec.gap);
    final pad = configOf(context).layout.sizeClassFor(MediaQuery.sizeOf(context).width).pagePadding;
    if (!spec.fill) {
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: pad),
        child: _Bricks(nodes, gap: gap, fill: false),
      );
    }
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: pad),
              child: _Bricks(nodes, gap: gap, fill: true),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bricks extends StatelessWidget {
  final List<BrickNode> nodes;
  final double gap;
  final bool fill;
  const _Bricks(this.nodes, {required this.gap, required this.fill});

  @override
  Widget build(BuildContext context) {
    final scope = BrickScope.of(context);
    Widget one(BrickNode n) {
      final flex = fill && brickFlexes(n);
      final child = scope.withFill(flex, Builder(builder: (context) => buildBrick(context, n)));
      if (!flex) return child;
      // Loose, so a brick with a height cap (the doors' max_height) can stay smaller; the column centres what is left.
      return n.brick == 'spacer' ? const Spacer() : Flexible(child: child);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, n) in nodes.where(scope.shows).indexed) ...[if (i > 0) SizedBox(height: gap), one(n)],
      ],
    );
  }
}
