"""Shape of config/media/upload_policy.yml: what an artisan may upload."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, field_validator

GCS_CHUNK_MULTIPLE_KIB = 256


class UploadPolicyRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    max_duration_seconds: int = Field(gt=0)
    allowed_mime_types: list[str] = Field(min_length=1)
    chunk_size_kib: int = Field(gt=0)

    @field_validator("chunk_size_kib")
    @classmethod
    def _gcs_multiple(cls, v: int) -> int:
        if v % GCS_CHUNK_MULTIPLE_KIB:
            raise ValueError(f"must be a multiple of {GCS_CHUNK_MULTIPLE_KIB} KiB (a GCS resumable-upload rule)")
        return v

    @field_validator("allowed_mime_types")
    @classmethod
    def _video_only(cls, v: list[str]) -> list[str]:
        bad = [m for m in v if not m.startswith("video/")]
        if bad:
            raise ValueError(f"only video/* types are allowed, got {bad}")
        return v
