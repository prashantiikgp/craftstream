/// Page scaffolding shared by screens: centred, padded content from layout.yml, and the standard
/// error panel with a retry button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../text/strings.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'surfaces.dart';
import 'tone.dart';

/// A vertically scrolling page whose content is padded and centred per the size class.
/// [maxWidth] narrows it further (forms).
class PageScroll extends ConsumerWidget {
  final List<Widget> children;
  final double? maxWidth;
  final EdgeInsetsGeometry? extraPadding;
  const PageScroll({super.key, required this.children, this.maxWidth, this.extraPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(appConfigProvider).layout;
    return LayoutBuilder(builder: (context, box) {
      final inset = layout.horizontalInset(box.maxWidth);
      final pad = layout.sizeClassFor(box.maxWidth).pagePadding;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(inset, pad, inset, pad * 2),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );
    });
  }
}

/// "Something went wrong" with a retry button: the error state of every async screen.
class LoadError extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  const LoadError({super.key, required this.onRetry, this.message});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Notice(
          tone: Tone.danger,
          title: context.s('common.error_title'),
          message: message ?? context.s('common.error_message'),
        ),
        SizedBox(height: context.tokens.space.md),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(context.s('common.retry'),
              onPressed: onRetry, variant: ButtonVariant.secondary, icon: Icons.refresh),
        ),
      ]);
}
