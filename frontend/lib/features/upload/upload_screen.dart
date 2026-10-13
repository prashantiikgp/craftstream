/// New product: details + process video, then a resumable upload with progress. Wide screens put the
/// details and the video side by side.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../shared/widgets/ds.dart';
import 'upload_controller.dart';
import 'widgets/upload_progress.dart';
import 'widgets/video_pick_card.dart';

class UploadScreen extends ConsumerWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(appConfigProvider).layout;
    final busy = ref.watch(uploadControllerProvider.select((s) => s.busy));
    final t = context.tokens;
    if (busy) {
      return PageScroll(maxWidth: layout.rules.formMaxWidth, children: const [UploadProgressView()]);
    }
    return LayoutBuilder(builder: (context, constraints) {
      final wide = layout.productSideBySide(constraints.maxWidth);
      final header = SectionHeader(context.s('upload.title'), subtitle: context.s('upload.subtitle'));
      if (!wide) {
        return PageScroll(maxWidth: layout.rules.formMaxWidth, children: [
          header,
          SizedBox(height: t.space.md),
          const _Details(),
          SizedBox(height: t.space.xl),
          const VideoPickCard(),
          SizedBox(height: t.space.xl),
          const _PublishButton(),
        ]);
      }
      return PageScroll(children: [
        header,
        SizedBox(height: t.space.md),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(flex: 6, child: AppCard(child: _Details())),
          SizedBox(width: t.space.xl),
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const VideoPickCard(),
              SizedBox(height: t.space.xl),
              const _PublishButton(),
            ]),
          ),
        ]),
      ]);
    });
  }
}

class _Details extends ConsumerStatefulWidget {
  const _Details();

  @override
  ConsumerState<_Details> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_Details> {
  late final UploadState _start = ref.read(uploadControllerProvider);
  late final _title = TextEditingController(text: _start.title);
  late final _description = TextEditingController(text: _start.description);
  late final _price = TextEditingController(text: _start.price);
  late final _otherTags = TextEditingController(text: _start.otherTags);
  late final _artisan = TextEditingController(text: _start.artisanName);

  @override
  void dispose() {
    for (final c in [_title, _description, _price, _otherTags, _artisan]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _error(UploadState s, UploadField field) {
    if (!s.showErrors) return null;
    return switch ((field, s.problems[field])) {
      (_, null) => null,
      (UploadField.title, FieldProblem.tooShort) => context.s('upload.title_too_short', {'min': titleMin}),
      (UploadField.title, FieldProblem.tooLong) => context.s('upload.title_too_long', {'max': titleMax}),
      (UploadField.description, FieldProblem.tooLong) =>
        context.s('upload.description_too_long', {'max': descriptionMax}),
      (UploadField.price, FieldProblem.invalid) => context.s('upload.price_invalid'),
      (UploadField.tags, FieldProblem.tooMany) => context.s('upload.tags_too_many', {'max': tagsMax}),
      (UploadField.artisan, FieldProblem.tooLong) => context.s('upload.artisan_too_long', {'max': artisanMax}),
      _ => context.s('upload.required'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = ref.watch(uploadControllerProvider);
    final c = ref.read(uploadControllerProvider.notifier);
    final featured = ref.watch(appConfigProvider).filters.rules.featuredTags;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppTextField(
        label: context.s('upload.title_label'),
        hint: context.s('upload.title_hint'),
        controller: _title,
        error: _error(s, UploadField.title),
        onChanged: c.setTitle,
      ),
      SizedBox(height: t.space.lg),
      AppTextField(
        label: context.s('upload.description_label'),
        hint: context.s('upload.description_hint'),
        controller: _description,
        maxLines: 4,
        error: _error(s, UploadField.description),
        onChanged: c.setDescription,
      ),
      SizedBox(height: t.space.lg),
      AppTextField(
        label: context.s('upload.price_label'),
        hint: context.s('upload.price_hint'),
        controller: _price,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        prefix: Padding(
          padding: EdgeInsets.only(left: t.space.lg, right: t.space.sm),
          child: Center(
            widthFactor: 1,
            child: Text(context.s('upload.currency_symbol'), style: context.type.bodyStrong),
          ),
        ),
        error: _error(s, UploadField.price),
        onChanged: c.setPrice,
      ),
      SizedBox(height: t.space.lg),
      Text(context.s('upload.tags_label'), style: context.type.label),
      SizedBox(height: t.space.sm),
      Wrap(spacing: t.space.sm, runSpacing: t.space.sm, children: [
        for (final tag in featured) TagChip(tag, selected: s.tags.contains(tag), onSelected: (_) => c.toggleTag(tag)),
      ]),
      SizedBox(height: t.space.md),
      AppTextField(
        label: context.s('upload.other_tags_label'),
        hint: context.s('upload.other_tags_hint'),
        helper: context.s('upload.tags_helper', {'max': tagsMax}),
        controller: _otherTags,
        error: _error(s, UploadField.tags),
        onChanged: c.setOtherTags,
      ),
      SizedBox(height: t.space.lg),
      AppTextField(
        label: context.s('upload.artisan_label'),
        hint: context.s('upload.artisan_hint'),
        helper: context.s('upload.artisan_helper'),
        controller: _artisan,
        error: _error(s, UploadField.artisan),
        onChanged: c.setArtisanName,
      ),
    ]);
  }
}

class _PublishButton extends ConsumerWidget {
  const _PublishButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final s = ref.watch(uploadControllerProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (s.showErrors && s.problems.isNotEmpty) ...[
        Notice(tone: Tone.danger, title: context.s('upload.fix_title'), message: context.s('upload.fix_message')),
        SizedBox(height: t.space.md),
      ],
      AppButton(
        context.s('upload.publish'),
        icon: Icons.cloud_upload_outlined,
        size: ButtonSize.lg,
        expand: true,
        onPressed: ref.read(uploadControllerProvider.notifier).publish,
      ),
      SizedBox(height: t.space.sm),
      Text(context.s('upload.publish_note'),
          textAlign: TextAlign.center, style: context.type.caption.copyWith(color: t.sub)),
    ]);
  }
}
