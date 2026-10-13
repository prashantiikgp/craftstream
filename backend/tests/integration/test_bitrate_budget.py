"""R5: the lowest rung, encoded with the real ladder settings, must fit the 50 kbps budget on the wire.

Encodes a short, deliberately hard clip (motion + film grain) with FFmpeg using ladder_engine's settings
and measures playlists + init + segments + HTTP headers. Skipped when FFmpeg isn't installed.
"""

from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

from app.domain.media.ladder_engine import sorted_rungs
from app.domain.media.ladder_loader import load_ladder_rules

ROOT = Path(__file__).resolve().parents[3]


def _local_hls():
    spec = importlib.util.spec_from_file_location("local_hls", ROOT / "tools" / "local_hls.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # dataclasses look their module up here
    spec.loader.exec_module(module)
    return module


hls = _local_hls()
pytestmark = pytest.mark.skipif(not hls.has_ffmpeg(), reason="FFmpeg not installed (sudo apt install ffmpeg)")


@pytest.fixture(scope="module")
def hard_clip(tmp_path_factory) -> Path:
    """24 s of moving test pattern with heavy grain: worse than real workshop footage."""
    src = tmp_path_factory.mktemp("src") / "hard.mp4"
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "lavfi", "-i", "testsrc2=size=854x480:rate=30",
        "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
        "-t", "24", "-vf", "noise=alls=30:allf=t+u", "-c:v", "libx264", "-preset", "ultrafast", "-crf", "20",
        "-c:a", "aac", "-b:a", "96k", str(src),
    ], check=True)
    return src


def test_lowest_rung_fits_budget_on_the_wire(hard_clip, tmp_path):
    lowest = sorted_rungs()[0].name
    hls.encode(hard_clip, tmp_path, only=lowest, quiet=True)
    m = hls.measure(tmp_path, lowest)
    budget = load_ladder_rules().max_lowest_rung_total_kbps
    assert m.segments >= 3
    assert m.on_wire_kbps <= budget, f"{lowest}: {m.on_wire_kbps:.1f} kbps on the wire > {budget} kbps"
