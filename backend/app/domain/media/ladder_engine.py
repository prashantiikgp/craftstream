"""Turn the ladder rules into encoder settings. Pure logic: builds configs, never runs anything.

Two outputs from the same rules, so local measurements predict what GCP produces:
  build_job_config(...)  -> Transcoder API JobConfig (submitted by app/infra/gcp/transcoder.py)
  ffmpeg_args(...)       -> FFmpeg command for one rung (run by tools/local_hls.py)

GCP input and output object names, the manifest name and the thumbnail prefix come from
media/storage_layout.yml (storage_layout_engine).
"""

from __future__ import annotations

from app.domain.media import storage_layout_engine as layout
from app.domain.media.ladder_loader import load_ladder_rules
from app.schemas.media.ladder_schema import LadderRules, Rung
from app.schemas.media.storage_layout_schema import StorageLayoutRules


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
    storage: StorageLayoutRules | None = None,
) -> dict:
    """Return the Transcoder API JobConfig as a plain dict (easy to inspect and test).

    With `max_duration_seconds`, the job only encodes the first N seconds of `input_uri` (an editList),
    so the server enforces the upload limit even if the app's own check is bypassed.
    """
    rules = rules or load_ladder_rules()
    if max_duration_seconds is not None and not input_uri:
        raise ValueError("input_uri is required when capping the duration")
    enc = rules.encoder.transcoder
    seg = f"{rules.segment_seconds}s"
    elementary, mux = [], []

    for r in sorted_rungs(rules):
        elementary.append({
            "key": f"video-{r.name}",
            "videoStream": {rules.video_codec: {
                "widthPixels": r.width,
                "heightPixels": r.height,
                "frameRate": r.fps,
                "bitrateBps": r.video_kbps * 1000,
                "gopDuration": f"{rules.keyframe_seconds}s",
                "profile": h264_profile(r, rules),
                "rateControlMode": enc.rate_control,
            }},
        })
        elementary.append({
            "key": f"audio-{r.name}",
            "audioStream": {
                "codec": enc.audio_codecs[r.audio_profile],
                "bitrateBps": r.audio_kbps * 1000,
                "channelCount": rules.audio.channels,
                "channelLayout": list(enc.channel_layouts[rules.audio.channels]),
                "sampleRateHertz": rules.audio.sample_rate,
            },
        })
        for kind in ("video", "audio"):  # one stream per mux stream (an fMP4 rule)
            mux.append({
                "key": f"{kind}-{r.name}-{enc.container}",
                "container": enc.container,
                "elementaryStreams": [f"{kind}-{r.name}"],
                "segmentSettings": {"segmentDuration": seg},
            })

    grid = enc.sprite_grid
    config: dict = {
        "elementaryStreams": elementary,
        "muxStreams": mux,
        "manifests": [{"fileName": layout.manifest_name(storage), "type": enc.manifest_type,
                       "muxStreams": [m["key"] for m in mux]}],
        "spriteSheets": [{
            "filePrefix": layout.thumbnail_prefix(storage),
            "spriteWidthPixels": rules.thumbnail.width,
            "spriteHeightPixels": rules.thumbnail.height,
            "quality": rules.thumbnail.jpeg_quality,
            "columnCount": grid.columns, "rowCount": grid.rows, "totalCount": grid.count,
        }],
    }
    if pubsub_topic:
        config["pubsubDestination"] = {"topic": pubsub_topic}  # the job result goes to the API via Pub/Sub
    if input_uri:
        config["inputs"] = [{"key": enc.input_key, "uri": input_uri}]
    if max_duration_seconds is not None:
        config["editList"] = [{"key": enc.edit_atom_key, "inputs": [enc.input_key],
                               "endTimeOffset": f"{max_duration_seconds}s"}]
    return config


def h264_profile(rung: Rung, rules: LadderRules | None = None) -> str:
    """The first encoder.h264_profiles entry whose max_height fits the rung."""
    rules = rules or load_ladder_rules()
    return next(p.profile for p in rules.encoder.h264_profiles if p.max_height is None or rung.height <= p.max_height)


def ffmpeg_args(
    rung: Rung,
    src: str,
    out_dir: str,
    rules: LadderRules | None = None,
    *,
    he_aac_available: bool = False,
    max_duration_seconds: int | None = None,
) -> list[str]:
    """FFmpeg command producing one rung as HLS (init segment + media segments + playlist) in `out_dir`.

    Matches the Transcoder job: same size, fps, bitrates, GOP, profile, audio and segment length.
    Without libfdk_aac, HE-AAC rungs fall back to AAC-LC at the same bitrate (same size, lower quality).
    """
    rules = rules or load_ladder_rules()
    ff = rules.encoder.ffmpeg
    gop = rung.fps * rules.keyframe_seconds
    if rung.audio_profile == "he-aac" and he_aac_available:
        audio = ["-c:a", ff.he_aac.codec, "-profile:a", ff.he_aac.profile]
    else:
        audio = ["-c:a", ff.audio_codec]
    cap = ["-t", str(max_duration_seconds)] if max_duration_seconds else []
    return [
        "ffmpeg", "-y", "-loglevel", ff.log_level, "-i", src, *cap,
        "-vf", (f"scale={rung.width}:{rung.height}:force_original_aspect_ratio=decrease,"
                f"pad={rung.width}:{rung.height}:(ow-iw)/2:(oh-ih)/2,fps={rung.fps}"),
        "-c:v", ff.video_codec, "-preset", ff.preset, "-profile:v", h264_profile(rung, rules),
        "-b:v", f"{rung.video_kbps}k", "-maxrate", f"{int(rung.video_kbps * ff.maxrate_factor)}k",
        "-bufsize", f"{int(rung.video_kbps * ff.bufsize_factor)}k",
        "-g", str(gop), "-keyint_min", str(gop), "-sc_threshold", "0",
        *audio, "-b:a", f"{rung.audio_kbps}k", "-ac", str(rules.audio.channels),
        "-ar", str(rules.audio.sample_rate),
        "-f", "hls", "-hls_time", str(rules.segment_seconds), "-hls_playlist_type", ff.playlist_type,
        "-hls_segment_type", ff.segment_type, "-hls_fmp4_init_filename", ff.init_segment,
        "-hls_segment_filename", f"{out_dir}/{ff.segment_pattern}",
        f"{out_dir}/{ff.playlist}",
    ]


def master_playlist(rungs: list[Rung], rules: LadderRules | None = None, *, headroom: float | None = None) -> str:
    """HLS master playlist listing each rung's folder, lowest first (players try the first entry first)."""
    rules = rules or load_ladder_rules()
    mp = rules.encoder.master_playlist
    headroom = mp.bandwidth_headroom if headroom is None else headroom
    lines = ["#EXTM3U", f"#EXT-X-VERSION:{mp.hls_version}"]
    for r in rungs:
        bw = int(r.total_kbps * 1000 * headroom)
        lines += [f"#EXT-X-STREAM-INF:BANDWIDTH={bw},RESOLUTION={r.width}x{r.height}",
                  f"{r.name}/{rules.encoder.ffmpeg.playlist}"]
    return "\n".join(lines) + "\n"
