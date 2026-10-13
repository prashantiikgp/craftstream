import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../shared/widgets/ds.dart';
import '../upload_controller.dart';

/// Everything after Publish: resumable upload progress (pause, resume, survive a drop), then processing,
/// then live or failed.
class UploadProgressView extends ConsumerWidget {
  const UploadProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final s = ref.watch(uploadControllerProvider);
    final controller = ref.read(uploadControllerProvider.notifier);
    final devTools = ref.watch(appConfigProvider).env.devTools;
    final video = s.video!;
    final arrived = s.total > 0 && s.sent >= s.total;
    final transferring = const {UploadPhase.uploading, UploadPhase.reconnecting, UploadPhase.paused}.contains(s.phase);
    final percent = (s.fraction * 100).floor();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.title.trim(), style: context.type.h2),
      SizedBox(height: t.space.xs),
      Text(
        context.s('upload.progress_subtitle', {'price': formatMoney(s.priceValue ?? 0, 'INR'), 'artisan': s.artisanName.trim()}),
        style: context.type.body.copyWith(color: t.sub),
      ),
      SizedBox(height: t.space.xl),
      AppCard(
        variant: CardVariant.elevated,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(arrived ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined, color: t.brandInk),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Text(
                s.phase == UploadPhase.creating
                    ? context.s('upload.creating')
                    : context.s(arrived ? 'upload.uploaded_file' : 'upload.uploading_file', {'name': video.name}),
                style: context.type.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (s.phase == UploadPhase.paused) StatusBadge(context.s('upload.paused_badge')),
          ]),
          SizedBox(height: t.space.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(t.radius.pill),
            child: LinearProgressIndicator(
              value: s.phase == UploadPhase.creating ? null : s.fraction,
              minHeight: 8,
            ),
          ),
          SizedBox(height: t.space.sm),
          Text(
            context.s('upload.progress_bytes',
                {'sent': formatBytes(s.sent), 'total': formatBytes(s.total), 'percent': percent}),
            style: context.type.caption.copyWith(color: t.sub),
          ),
          if (s.ticket != null) ...[
            SizedBox(height: t.space.xxs),
            Text(context.s('upload.chunk_note', {'chunk': formatBytes(s.ticket!.chunkSizeBytes)}),
                style: context.type.caption.copyWith(color: t.sub)),
          ],
          if (transferring) ...[
            SizedBox(height: t.space.lg),
            Wrap(spacing: t.space.sm, runSpacing: t.space.sm, children: [
              if (s.phase == UploadPhase.paused)
                AppButton(context.s('upload.resume'), icon: Icons.play_arrow_rounded, onPressed: controller.resume)
              else
                AppButton(context.s('upload.pause'),
                    icon: Icons.pause_rounded, variant: ButtonVariant.secondary, onPressed: controller.pause),
              if (devTools && s.phase == UploadPhase.uploading)
                AppButton(context.s('upload.simulate_drop'),
                    icon: Icons.wifi_off, variant: ButtonVariant.ghost, onPressed: controller.simulateDrop),
            ]),
          ],
        ]),
      ),
      SizedBox(height: t.space.lg),
      ..._status(context, ref, s),
    ]);
  }

  List<Widget> _status(BuildContext context, WidgetRef ref, UploadState s) {
    final t = context.tokens;
    final controller = ref.read(uploadControllerProvider.notifier);
    final productId = s.ticket?.product.id;
    switch (s.phase) {
      case UploadPhase.reconnecting:
        return [
          Notice(
            tone: Tone.warning,
            icon: Icons.wifi_off,
            title: context.s('upload.reconnecting_title'),
            message: context.s('upload.reconnecting', {'sent': formatBytes(s.sent), 'attempt': s.retries}),
          ),
        ];
      case UploadPhase.paused:
        return [
          Notice(tone: Tone.info, title: context.s('upload.paused_title'), message: context.s('upload.paused_message')),
        ];
      case UploadPhase.processing:
        return [
          Notice(
            tone: Tone.info,
            icon: Icons.auto_awesome_outlined,
            title: context.s('upload.processing_title'),
            message: context.s(s.pollGaveUp ? 'upload.processing_slow' : 'upload.processing_message'),
          ),
          SizedBox(height: t.space.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(t.radius.pill),
            child: const LinearProgressIndicator(minHeight: 4),
          ),
          SizedBox(height: t.space.lg),
          AppButton(context.s('upload.go_to_products'),
              variant: ButtonVariant.secondary, onPressed: () => context.go('/studio')),
        ];
      case UploadPhase.live:
        return [
          Notice(
            tone: Tone.success,
            title: context.s('upload.live_title'),
            message: context.s('upload.live_message', {'title': s.title.trim()}),
          ),
          SizedBox(height: t.space.lg),
          Wrap(spacing: t.space.sm, runSpacing: t.space.sm, children: [
            if (productId != null)
              AppButton(context.s('upload.view_product'),
                  icon: Icons.visibility_outlined, onPressed: () => context.push('/product/$productId')),
            AppButton(context.s('upload.add_another'),
                variant: ButtonVariant.secondary, icon: Icons.add, onPressed: controller.reset),
          ]),
        ];
      case UploadPhase.failed:
        final canResume = s.ticket != null && s.sent < s.total;
        return [
          Notice(
            tone: Tone.danger,
            title: context.s(canResume ? 'upload.failed_title' : 'upload.processing_failed_title'),
            message: s.error ?? context.s(canResume ? 'upload.failed_message' : 'upload.processing_failed_message'),
          ),
          SizedBox(height: t.space.lg),
          Wrap(spacing: t.space.sm, runSpacing: t.space.sm, children: [
            if (canResume)
              AppButton(context.s('upload.resume'), icon: Icons.refresh, onPressed: controller.resume),
            AppButton(context.s('upload.start_over'),
                variant: canResume ? ButtonVariant.secondary : ButtonVariant.primary, onPressed: controller.reset),
          ]),
        ];
      case UploadPhase.editing || UploadPhase.creating || UploadPhase.uploading:
        return [
          Notice(tone: Tone.info, title: context.s('upload.keep_open_title'), message: context.s('upload.keep_open_message')),
        ];
    }
  }
}
