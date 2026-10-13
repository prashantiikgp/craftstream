/// A listing's video_status as a badge: Live, Processing, Failed or Waiting for video.
library;

import 'package:flutter/material.dart';

import '../text/strings.dart';
import 'indicators.dart';
import 'tone.dart';

class VideoStatusBadge extends StatelessWidget {
  final String status;
  const VideoStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) => switch (status) {
        'ready' => StatusBadge(context.s('status.ready'), tone: Tone.success, dot: true),
        'processing' => StatusBadge(context.s('status.processing'), tone: Tone.warning, dot: true),
        'failed' => StatusBadge(context.s('status.failed'), tone: Tone.danger),
        _ => StatusBadge(context.s('status.awaiting_upload')),
      };
}
