"""Turn the ladder rules into encoder settings. Pure logic: builds configs, never runs anything.

Two outputs from the same rules, so local measurements predict what GCP produces:
  build_job_config(...)  -> Transcoder API JobConfig (submitted by app/infra/gcp/transcoder.py)
  ffmpeg_args(...)       -> FFmpeg command for one rung (run by tools/local_hls.py)

GCP input:  gs://$UPLOAD_BUCKET/raw/<product_id>/source
GCP output: gs://$MEDIA_BUCKET/hls/<product_id>/manifest.m3u8 (+ one playlist and chunks per rung)
"""

from __future__ import annotations

from app.domain.media.ladder_loader import load_ladder_rules
from app.schemas.media.ladder_schema import LadderRules, Rung


def sorted_rungs(rules: LadderRules | None = None) -> list[Rung]:
    """Rungs from lowest to highest total bitrate."""
    rules = rules or load_ladder_rules()
    return sorted(rules.rungs, key=lambda r: r.total_kbps)


def lowest_rung_within_budget(rules: LadderRules | None = None) -> bool:
    rules = rules or load_ladder_rules()
    return sorted_rungs(rules)[0].total_kbps <= rules.max_lowest_rung_total_kbps


def build_job_config(
    rules: LadderRules | None = None,
    *,
    input_uri: str | None = None,
    max_duration_seconds: int | None = None,
    pubsub_topic: str | None = None,
) -> dict:
    """Return the Transcoder API JobConfig as a plain dict (easy to inspect and test).

    With `max_duration_seconds`, the job only encodes the first N seconds of `input_uri` (an editList),
    so the server enforces the upload limit even if the app's own check is bypassed.
    """
    rules = rules or load_ladder_rules()
    if max_duration_seconds is not None and not input_uri:
        raise ValueError("input_uri is required when capping the duration")
    seg = f"{rules.segment_seconds}s"
    elementary, mux = [], []

    for r in sorted_rungs(rules):
        elementary.append({
            "key": f"video-{r.name}",
            "videoStream": {"h264": {
                "widthPixels": r.width,
                "heightPixels": r.height,
                "frameRate": r.fps,
                "bitrateBps": r.video_kbps * 1000,
                "gopDuration": f"{rules.keyframe_seconds}s",
                "profile": h264_profile(r),
                "rateControlMode": "vbr",
            }},
        })
        elementary.append({
            "key": f"audio-{r.name}",
            "audioStream": {
                "codec": "aac-he" if r.audio_profile == "he-aac" else "aac",
                "bitrateBps": r.audio_kbps * 1000,
                "channelCount": rules.audio.channels,
                # The API defaults to a stereo layout and rejects a count that doesn't match it.
                "channelLayout": ["fc"] if rules.audio.channels == 1 else ["fl", "fr"],
                "sampleRateHertz": rules.audio.sample_rate,
            },
        })
        # fMP4 segments: ~14 kbps less container overhead than TS at these tiny bitrates
        # (measured: 56.7 -> 42.0 kbps on the 144p rung). fMP4 mux streams hold one stream each.
        for kind in ("video", "audio"):
            mux.append({
                "key": f"{kind}-{r.name}-fmp4",
                "container": "fmp4",
                "elementaryStreams": [f"{kind}-{r.name}"],
                "segmentSettings": {"segmentDuration": seg},
            })

    config: dict = {
        "elementaryStreams": elementary,
        "muxStreams": mux,
        "manifests": [{"fileName": "manifest.m3u8", "type": "HLS", "muxStreams": [m["key"] for m in mux]}],
        "spriteSheets": [{"filePrefix": "thumb", "spriteWidthPixels": 320, "spriteHeightPixels": 180,
                          "columnCount": 1, "rowCount": 1, "totalCount": 1}],
    }
    if pubsub_topic:
        config["pubsubDestination"] = {"topic": pubsub_topic}  # job result -> /internal/media/transcoded
    if input_uri:
        config["inputs"] = [{"key": "input0", "uri": input_uri}]
    if max_duration_seconds is not None:
        config["editList"] = [{"key": "atom0", "inputs": ["input0"], "endTimeOffset": f"{max_duration_seconds}s"}]
    return config


def h264_profile(rung: Rung) -> str:
    return "baseline" if rung.height <= 240 else "main"


def ffmpeg_args(
    rung: Rung,
    src: str,
    out_dir: str,
    rules: LadderRules | None = None,
    *,
    he_aac_available: bool = False,
    max_duration_seconds: int | None = None,
) -> list[str]:
    """FFmpeg command producing one rung as fMP4 HLS (init.mp4 + seg_NNNN.m4s + index.m3u8) in `out_dir`.

    Matches the Transcoder job: same size, fps, bitrates, GOP, profile, audio and segment length.
    Without libfdk_aac, HE-AAC rungs fall back to AAC-LC at the same bitrate (same size, lower quality).
    """
    rules = rules or load_ladder_rules()
    gop = rung.fps * rules.keyframe_seconds
    if rung.audio_profile == "he-aac" and he_aac_available:
        audio = ["-c:a", "libfdk_aac", "-profile:a", "aac_he"]
    else:
        audio = ["-c:a", "aac"]
    cap = ["-t", str(max_duration_seconds)] if max_duration_seconds else []
    return [
        "ffmpeg", "-y", "-loglevel", "error", "-i", src, *cap,
        "-vf", (f"scale={rung.width}:{rung.height}:force_original_aspect_ratio=decrease,"
                f"pad={rung.width}:{rung.height}:(ow-iw)/2:(oh-ih)/2,fps={rung.fps}"),
        "-c:v", "libx264", "-preset", "veryslow", "-profile:v", h264_profile(rung),
        "-b:v", f"{rung.video_kbps}k", "-maxrate", f"{int(rung.video_kbps * 1.2)}k",
        "-bufsize", f"{rung.video_kbps * 2}k",
        "-g", str(gop), "-keyint_min", str(gop), "-sc_threshold", "0",
        *audio, "-b:a", f"{rung.audio_kbps}k", "-ac", str(rules.audio.channels),
        "-ar", str(rules.audio.sample_rate),
        "-f", "hls", "-hls_time", str(rules.segment_seconds), "-hls_playlist_type", "vod",
        "-hls_segment_type", "fmp4", "-hls_fmp4_init_filename", "init.mp4",
        "-hls_segment_filename", f"{out_dir}/seg_%04d.m4s",
        f"{out_dir}/index.m3u8",
    ]


def master_playlist(rungs: list[Rung], headroom: float = 1.1) -> str:
    """HLS master playlist listing each rung's folder, lowest first (players try the first entry first)."""
    lines = ["#EXTM3U", "#EXT-X-VERSION:7"]
    for r in rungs:
        bw = int(r.total_kbps * 1000 * headroom)
        lines += [f"#EXT-X-STREAM-INF:BANDWIDTH={bw},RESOLUTION={r.width}x{r.height}", f"{r.name}/index.m3u8"]
    return "\n".join(lines) + "\n"
