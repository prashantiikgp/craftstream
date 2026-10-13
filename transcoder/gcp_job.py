"""Build and submit a Google Cloud Transcoder API job from the YAML ladder.

Input:  gs://$UPLOAD_BUCKET/raw/<product_id>/source
Output: gs://$MEDIA_BUCKET/hls/<product_id>/manifest.m3u8 (+ one playlist and chunks per rung)
"""

from __future__ import annotations

import os

from .ladder import load_ladder


def build_job_config(product_id: str) -> dict:
    """Return the Transcoder API JobConfig as a plain dict (easy to inspect and test)."""
    spec, rungs = load_ladder()
    seg = f"{spec['segment_seconds']}s"
    elementary, mux = [], []

    for r in rungs:
        elementary.append({
            "key": f"video-{r.name}",
            "videoStream": {"h264": {
                "widthPixels": r.width,
                "heightPixels": r.height,
                "frameRate": r.fps,
                "bitrateBps": r.video_kbps * 1000,
                "gopDuration": f"{spec['keyframe_seconds']}s",
                "profile": "baseline" if r.height <= 240 else "main",
                "rateControlMode": "vbr",
            }},
        })
        elementary.append({
            "key": f"audio-{r.name}",
            "audioStream": {
                "codec": "aac-he" if r.audio_profile == "he-aac" else "aac",
                "bitrateBps": r.audio_kbps * 1000,
                "channelCount": spec["audio"]["channels"],
                "sampleRateHertz": spec["audio"]["sample_rate"],
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


def submit_job(product_id: str) -> str:
    from google.cloud.video import transcoder_v1

    project = os.environ["GCP_PROJECT"]
    region = os.environ.get("GCP_REGION", "asia-south1")
    client = transcoder_v1.TranscoderServiceClient()
    job = transcoder_v1.Job(
        input_uri=f"gs://{os.environ['UPLOAD_BUCKET']}/raw/{product_id}/source",
        output_uri=f"gs://{os.environ['MEDIA_BUCKET']}/hls/{product_id}/",
        config=transcoder_v1.JobConfig(build_job_config(product_id)),
        labels={"product_id": product_id},
    )
    # TODO(step 2): set job.config.pubsub_destination so the API calls /transcode-callback when done.
    result = client.create_job(parent=f"projects/{project}/locations/{region}", job=job)
    return result.name
