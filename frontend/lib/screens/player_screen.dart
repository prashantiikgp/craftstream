// Plays the product's HLS stream. On Android, video_player uses ExoPlayer (adaptive bitrate built in);
// on Chrome, video_player_web_hls uses hls.js. Both drop to the 144p rung when bandwidth is ~50 kbps.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/generated/models.dart';

class PlayerScreen extends StatefulWidget {
  final Product product;
  const PlayerScreen({super.key, required this.product});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final url = widget.product.hlsUrl;
    if (url != null) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url), formatHint: VideoFormat.hls)
        ..initialize().then((_) => setState(() {}));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(title: Text(p.title)),
      body: ListView(children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: c == null
              ? const Center(child: Text('Video not available'))
              : !c.value.isInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(alignment: Alignment.bottomCenter, children: [
                      VideoPlayer(c),
                      VideoProgressIndicator(c, allowScrubbing: true),
                    ]),
        ),
        if (c != null)
          IconButton(
            iconSize: 40,
            icon: ValueListenableBuilder(
              valueListenable: c,
              builder: (_, v, __) => Icon(v.isPlaying ? Icons.pause_circle : Icons.play_circle),
            ),
            onPressed: () => c.value.isPlaying ? c.pause() : c.play(),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(p.description),
        ),
      ]),
    );
  }
}
