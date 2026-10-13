import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/ds.dart';
import '../upload_controller.dart';

/// Pick the process video and see at once whether it fits the server's limit (GET /upload-policy).
class VideoPickCard extends ConsumerWidget {
  const VideoPickCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(uploadControllerProvider);
    final controller = ref.read(uploadControllerProvider.notifier);
    final policy = ref.watch(uploadPolicyProvider).value;
    final video = state.video;
    final max = policy == null ? null : formatDuration(Duration(seconds: policy.maxDurationSeconds));
    final missing = state.showErrors && video == null;

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.s('upload.video_label'), style: context.type.label),
        SizedBox(height: t.space.md),
        if (video == null) ...[
          Container(
            padding: EdgeInsets.all(t.space.xl),
            decoration: BoxDecoration(
              color: t.brandLl,
              borderRadius: BorderRadius.circular(t.radius.md),
              border: Border.all(color: missing ? t.danger.fill : t.brandLine),
            ),
            child: Column(children: [
              Icon(Icons.video_call_outlined, size: 40, color: t.brandInk),
              SizedBox(height: t.space.sm),
              Text(context.s('upload.video_empty_title'), style: context.type.title, textAlign: TextAlign.center),
              SizedBox(height: t.space.xs),
              Text(
                max == null ? context.s('upload.video_empty_message_loading') : context.s('upload.video_empty_message', {'max': max}),
                style: context.type.caption.copyWith(color: t.sub),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: t.space.lg),
              AppButton(context.s('upload.choose_video'), icon: Icons.folder_open, onPressed: controller.pickVideo),
            ]),
          ),
          if (missing) ...[
            SizedBox(height: t.space.xs),
            Text(context.s('upload.video_required'), style: context.type.caption.copyWith(color: t.danger.ink)),
          ],
        ] else ...[
          Row(children: [
            Container(
              padding: EdgeInsets.all(t.space.md),
              decoration: BoxDecoration(color: t.brandLl, borderRadius: BorderRadius.circular(t.radius.sm)),
              child: Icon(Icons.movie_outlined, color: t.brandInk),
            ),
            SizedBox(width: t.space.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(video.name, style: context.type.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: t.space.xxs),
                Text(
                  [formatBytes(video.sizeBytes), if (video.duration != null) formatDuration(video.duration!)].join(' · '),
                  style: context.type.caption.copyWith(color: t.sub),
                ),
              ]),
            ),
            AppButton(context.s('upload.change_video'),
                variant: ButtonVariant.ghost, size: ButtonSize.sm, onPressed: controller.pickVideo),
          ]),
          if (policy != null) ...[
            SizedBox(height: t.space.md),
            switch (checkVideo(video, policy)) {
              VideoCheck.ok => Notice(
                  tone: Tone.success,
                  title: context.s('upload.check_ok_title'),
                  message: context.s('upload.check_ok', {'duration': formatDuration(video.duration!), 'max': max!}),
                ),
              VideoCheck.tooLong => Notice(
                  tone: Tone.danger,
                  title: context.s('upload.check_too_long_title'),
                  message: context.s('upload.check_too_long', {'duration': formatDuration(video.duration!), 'max': max!}),
                ),
              VideoCheck.unknownLength => Notice(
                  tone: Tone.info,
                  title: context.s('upload.check_unknown_title'),
                  message: context.s('upload.check_unknown', {'max': max!}),
                ),
              VideoCheck.badType => Notice(
                  tone: Tone.danger,
                  title: context.s('upload.check_bad_type_title'),
                  message: context.s('upload.check_bad_type'),
                ),
            },
          ],
        ],
      ]),
    );
  }
}
