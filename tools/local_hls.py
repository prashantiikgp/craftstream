"""Make the same HLS ladder locally with FFmpeg, to test quality and bitrate before using GCP.

    make hls SRC=my_video.mp4                                                    # all rungs
    backend/.venv/bin/python tools/local_hls.py my_video.mp4 out/ --only ultra_low   # one rung

Uses the same ladder rules (backend/config/media/ladder.yml) as the GCP Transcoder job.

Then open out/manifest.m3u8 in VLC, or serve the folder and play it in the app.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.domain.media.ladder_engine import sorted_rungs
from app.domain.media.ladder_loader import load_ladder_rules


def encode(src: Path, out: Path, only: str | None = None) -> None:
    spec = load_ladder_rules()
    rungs = sorted_rungs(spec)
    if only:
        rungs = [r for r in rungs if r.name == only]
    out.mkdir(parents=True, exist_ok=True)
    seg = spec.segment_seconds

    for r in rungs:
        rung_dir = out / r.name
        rung_dir.mkdir(exist_ok=True)
        audio = ["-c:a", "libfdk_aac", "-profile:a", "aac_he"] if r.audio_profile == "he-aac" and _has_fdk() else ["-c:a", "aac"]
        cmd = [
            "ffmpeg", "-y", "-loglevel", "error", "-i", str(src),
            "-vf", (f"scale={r.width}:{r.height}:force_original_aspect_ratio=decrease,"
                    f"pad={r.width}:{r.height}:(ow-iw)/2:(oh-ih)/2,fps={r.fps}"),
            "-c:v", "libx264", "-preset", "veryslow", "-profile:v", "baseline" if r.height <= 240 else "main",
            "-b:v", f"{r.video_kbps}k", "-maxrate", f"{int(r.video_kbps * 1.2)}k", "-bufsize", f"{r.video_kbps * 2}k",
            "-g", str(r.fps * spec.keyframe_seconds), "-keyint_min", str(r.fps * spec.keyframe_seconds),
            "-sc_threshold", "0",
            *audio, "-b:a", f"{r.audio_kbps}k", "-ac", str(spec.audio.channels),
            "-ar", str(spec.audio.sample_rate),
            "-f", "hls", "-hls_time", str(seg), "-hls_playlist_type", "vod", "-hls_segment_type", "fmp4",
            "-hls_fmp4_init_filename", "init.mp4",
            "-hls_segment_filename", str(rung_dir / "seg_%04d.m4s"),
            str(rung_dir / "index.m3u8"),
        ]
        print(f"encoding {r.name} ({r.width}x{r.height}@{r.fps}fps, {r.total_kbps} kbps) ...")
        subprocess.run(cmd, check=True)

    lines = ["#EXTM3U", "#EXT-X-VERSION:7"]
    for r in rungs:
        bw = int(r.total_kbps * 1000 * 1.1)
        lines += [f"#EXT-X-STREAM-INF:BANDWIDTH={bw},RESOLUTION={r.width}x{r.height}", f"{r.name}/index.m3u8"]
    (out / "manifest.m3u8").write_text("\n".join(lines) + "\n")
    print(f"done: {out / 'manifest.m3u8'}")


def _has_fdk() -> bool:
    res = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], check=False, capture_output=True, text=True)
    return "libfdk_aac" in res.stdout


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--only")
    a = ap.parse_args()
    encode(a.src, a.out, a.only)
