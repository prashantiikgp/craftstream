"""Shape of config/media/ladder.yml: the bitrate ladder every uploaded video is transcoded into."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class Rung(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    name: str
    width: int = Field(gt=0)
    height: int = Field(gt=0)
    fps: int = Field(gt=0)
    video_kbps: int = Field(gt=0)
    audio_kbps: int = Field(gt=0)
    audio_profile: Literal["he-aac", "aac-lc"]

    @property
    def total_kbps(self) -> int:
        return self.video_kbps + self.audio_kbps


class AudioSettings(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    codec: Literal["aac"]
    sample_rate: int = Field(gt=0)
    channels: int = Field(ge=1, le=2)


class LadderRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    segment_seconds: int = Field(gt=0)
    keyframe_seconds: int = Field(gt=0)
    video_codec: Literal["h264"]
    audio: AudioSettings
    rungs: list[Rung] = Field(min_length=1)
    max_lowest_rung_total_kbps: int = Field(gt=0)
