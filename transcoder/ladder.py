"""Read specs/media/ladder.yaml and turn it into encoder settings."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml

LADDER_FILE = Path(__file__).resolve().parents[1] / "specs" / "media" / "ladder.yaml"


@dataclass
class Rung:
    name: str
    width: int
    height: int
    fps: int
    video_kbps: int
    audio_kbps: int
    audio_profile: str

    @property
    def total_kbps(self) -> int:
        return self.video_kbps + self.audio_kbps


def load_ladder(path: Path = LADDER_FILE) -> tuple[dict, list[Rung]]:
    spec = yaml.safe_load(path.read_text())
    rungs = [Rung(**r) for r in spec["rungs"]]
    return spec, sorted(rungs, key=lambda r: r.total_kbps)
