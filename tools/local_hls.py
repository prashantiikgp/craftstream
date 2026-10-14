"""Build the HLS ladder locally with FFmpeg and measure what a player would download.

    make hls SRC=my_video.mp4                                                        # all rungs + report
    backend/.venv/bin/python tools/local_hls.py my_video.mp4 out/ --only ultra_low   # one rung
    backend/.venv/bin/python tools/local_hls.py --sample out/sample.mp4              # make a test clip

Encoder settings come from backend ladder_engine (the same rules as the GCP Transcoder job).
Open out/manifest.m3u8 in VLC, or serve the folder and play it in the app.

"On the wire" for a rung = master playlist + rung playlist + init segment + every media segment,
plus an allowance for HTTP response headers per request. That is what the 50 kbps budget is about.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.domain.media.ladder_engine import ffmpeg_args, master_playlist, sorted_rungs
from app.domain.media.ladder_loader import load_ladder_rules
from app.domain.media.storage_layout_engine import manifest_name
from app.domain.media.upload_policy_engine import max_duration_seconds

HTTP_HEADER_BYTES = 400  # typical GCS response headers per request (status line, cache, CORS, content-type)


@dataclass(frozen=True)
class Measurement:
    rung: str
    seconds: float              # media duration from the playlist
    segments: int
    payload_bytes: int          # playlists + init + segments
    requests: int               # HTTP requests a player makes for this rung
    peak_segment_kbps: float    # the heaviest single segment, as a bitrate over its own duration

    @property
    def payload_kbps(self) -> float:
        return self.payload_bytes * 8 / self.seconds / 1000

    @property
    def on_wire_kbps(self) -> float:
        return (self.payload_bytes + self.requests * HTTP_HEADER_BYTES) * 8 / self.seconds / 1000


def has_ffmpeg() -> bool:
    return shutil.which("ffmpeg") is not None


def has_fdk_aac() -> bool:
    res = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], check=False, capture_output=True, text=True)
    return "libfdk_aac" in res.stdout


def make_sample(dst: Path, seconds: int = 60, noisy: bool = False) -> Path:
    """A 1080p30 clip with motion (and optional film grain, which is much harder to compress) plus a tone."""
    vf = "noise=alls=25:allf=t+u" if noisy else "null"
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "lavfi", "-i", "testsrc2=size=1920x1080:rate=30",
        "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
        "-t", str(seconds), "-vf", vf, "-c:v", "libx264", "-preset", "veryfast", "-crf", "18",
        "-c:a", "aac", "-b:a", "128k", str(dst),
    ], check=True)
    return dst


def encode(src: Path, out: Path, only: str | None = None, quiet: bool = False) -> list[str]:
    rules = load_ladder_rules()
    rungs = [r for r in sorted_rungs(rules) if only in (None, r.name)]
    if not rungs:
        raise SystemExit(f"no rung named {only!r}")
    out.mkdir(parents=True, exist_ok=True)
    fdk = has_fdk_aac()
    for r in rungs:
        rung_dir = out / r.name
        rung_dir.mkdir(exist_ok=True)
        if not quiet:
            print(f"encoding {r.name} ({r.width}x{r.height}@{r.fps}fps, {r.total_kbps} kbps) ...")
        subprocess.run(ffmpeg_args(r, str(src), str(rung_dir), rules, he_aac_available=fdk,
                                   max_duration_seconds=max_duration_seconds()), check=True)
    (out / manifest_name()).write_text(master_playlist(rungs, rules))
    return [r.name for r in rungs]


def measure(out: Path, rung: str) -> Measurement:
    ff = load_ladder_rules().encoder.ffmpeg
    rung_dir = out / rung
    playlist = (rung_dir / ff.playlist).read_text()
    durations = [float(d) for d in re.findall(r"#EXTINF:([\d.]+)", playlist)]
    segment_rx = re.sub(r"%0?\d*d", r"\\d+", re.escape(ff.segment_pattern))  # seg_%04d.m4s -> seg_\d+\.m4s
    segment_files = re.findall(rf"^({segment_rx})$", playlist, flags=re.MULTILINE)
    seg_sizes = [(rung_dir / s).stat().st_size for s in segment_files]
    payload = ((out / manifest_name()).stat().st_size + (rung_dir / ff.playlist).stat().st_size
               + (rung_dir / ff.init_segment).stat().st_size + sum(seg_sizes))
    peak = max(size * 8 / d / 1000 for size, d in zip(seg_sizes, durations, strict=True))
    return Measurement(rung=rung, seconds=sum(durations), segments=len(seg_sizes), payload_bytes=payload,
                       requests=3 + len(seg_sizes), peak_segment_kbps=peak)


def report(measurements: list[Measurement]) -> str:
    budget = load_ladder_rules().max_lowest_rung_total_kbps
    lines = ["| Rung | Duration | Payload kbps | On the wire kbps | Peak segment kbps |", "|---|---|---|---|---|"]
    for m in measurements:
        lines.append(f"| {m.rung} | {m.seconds:.0f} s | {m.payload_kbps:.1f} | {m.on_wire_kbps:.1f} | "
                     f"{m.peak_segment_kbps:.1f} |")
    lowest = measurements[0]
    verdict = "within" if lowest.on_wire_kbps <= budget else "OVER"
    lines.append(f"\nLowest rung on the wire: {lowest.on_wire_kbps:.1f} kbps ({verdict} the {budget} kbps budget).")
    return "\n".join(lines)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src", type=Path, nargs="?")
    ap.add_argument("out", type=Path, nargs="?")
    ap.add_argument("--only", help="encode just this rung")
    ap.add_argument("--sample", type=Path, help="write a 60 s 1080p test clip here and exit")
    ap.add_argument("--noisy", action="store_true", help="with --sample: add film grain (worst case)")
    a = ap.parse_args()
    if not has_ffmpeg():
        raise SystemExit("ffmpeg not found: sudo apt install ffmpeg")
    if a.sample:
        print(f"wrote {make_sample(a.sample, noisy=a.noisy)}")
    elif a.src and a.out:
        names = encode(a.src, a.out, a.only)
        print(report([measure(a.out, n) for n in names]))
        print(f"\nplay: {a.out / manifest_name()}")
    else:
        ap.error("give SRC and OUT, or --sample PATH")
