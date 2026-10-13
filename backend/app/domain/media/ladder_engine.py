"""Turn the ladder rules into a Transcoder API JobConfig. Pure logic: no GCP calls here.

Input:  gs://$UPLOAD_BUCKET/raw/<product_id>/source
Output: gs://$MEDIA_BUCKET/hls/<product_id>/manifest.m3u8 (+ one playlist and chunks per rung)
Submitting the job lives in app/infra/gcp/transcoder.py.
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


def build_job_config(rules: LadderRules | None = None) -> dict:
    """Return the Transcoder API JobConfig as a plain dict (easy to inspect and test)."""
    rules = rules or load_ladder_rules()
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
                "profile": "baseline" if r.height <= 240 else "main",
                "rateControlMode": "vbr",
            }},
        })
        elementary.append({
            "key": f"audio-{r.name}",
            "audioStream": {
                "codec": "aac-he" if r.audio_profile == "he-aac" else "aac",
                "bitrateBps": r.audio_kbps * 1000,
                "channelCount": rules.audio.channels,
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

    return {
        "elementaryStreams": elementary,
        "muxStreams": mux,
        "manifests": [{"fileName": "manifest.m3u8", "type": "HLS", "muxStreams": [m["key"] for m in mux]}],
        "spriteSheets": [{"filePrefix": "thumb", "spriteWidthPixels": 320, "spriteHeightPixels": 180,
                          "columnCount": 1, "rowCount": 1, "totalCount": 1}],
    }
