"""Shape of config/media/ladder.yml: the bitrate ladder every uploaded video is transcoded into."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


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


class ThumbnailSettings(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    width: int = Field(gt=0)
    height: int = Field(gt=0)
    jpeg_quality: int = Field(ge=1, le=100)


class H264Profile(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    max_height: int | None = Field(None, gt=0)  # None: any height
    profile: Literal["baseline", "main", "high"]


class SpriteGrid(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    columns: int = Field(ge=1)
    rows: int = Field(ge=1)
    count: int = Field(ge=1)


class TranscoderEncoder(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    rate_control: Literal["vbr", "cbr"]
    container: Literal["fmp4", "ts"]
    manifest_type: Literal["HLS", "DASH"]
    audio_codecs: dict[Literal["he-aac", "aac-lc"], str]
    channel_layouts: dict[int, list[str]]
    sprite_grid: SpriteGrid
    input_key: str = Field(min_length=1)
    edit_atom_key: str = Field(min_length=1)

    @model_validator(mode="after")
    def _layouts_match_counts(self) -> TranscoderEncoder:
        bad = [n for n, layout in self.channel_layouts.items() if len(layout) != n]
        if bad:
            raise ValueError(f"channel_layouts must list one channel per count, wrong for {bad}")
        return self


class HeAac(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    codec: str = Field(min_length=1)
    profile: str = Field(min_length=1)


class FfmpegEncoder(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    video_codec: str = Field(min_length=1)
    preset: str = Field(min_length=1)
    audio_codec: str = Field(min_length=1)
    he_aac: HeAac
    maxrate_factor: float = Field(ge=1)
    bufsize_factor: float = Field(gt=0)
    log_level: str = Field(min_length=1)
    playlist_type: Literal["vod", "event"]
    segment_type: Literal["fmp4", "mpegts"]
    playlist: str = Field(min_length=1)
    init_segment: str = Field(min_length=1)
    segment_pattern: str = Field(min_length=1)


class MasterPlaylist(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    hls_version: int = Field(ge=1)
    bandwidth_headroom: float = Field(ge=1)


class EncoderSettings(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    h264_profiles: list[H264Profile] = Field(min_length=1)
    transcoder: TranscoderEncoder
    ffmpeg: FfmpegEncoder
    master_playlist: MasterPlaylist

    @model_validator(mode="after")
    def _last_profile_fits_any_height(self) -> EncoderSettings:
        if self.h264_profiles[-1].max_height is not None:
            raise ValueError("the last h264_profiles entry must have no max_height (it catches every rung)")
        return self


class LadderRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    segment_seconds: int = Field(gt=0)
    keyframe_seconds: int = Field(gt=0)
    video_codec: Literal["h264"]
    audio: AudioSettings
    rungs: list[Rung] = Field(min_length=1)
    thumbnail: ThumbnailSettings
    max_lowest_rung_total_kbps: int = Field(gt=0)
    encoder: EncoderSettings

    @model_validator(mode="after")
    def _every_rung_can_be_encoded(self) -> LadderRules:
        missing = sorted({r.audio_profile for r in self.rungs} - set(self.encoder.transcoder.audio_codecs))
        if missing:
            raise ValueError(f"encoder.transcoder.audio_codecs has no codec for {missing}")
        if self.audio.channels not in self.encoder.transcoder.channel_layouts:
            raise ValueError(f"encoder.transcoder.channel_layouts has no layout for {self.audio.channels} channel(s)")
        return self
