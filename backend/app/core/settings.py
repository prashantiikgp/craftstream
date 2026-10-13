"""Settings, read from environment variables (see .env.example). Validated at startup."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    # Real environment variables win over .env files; .env at the repo root or in backend/ (both gitignored).
    model_config = SettingsConfigDict(env_file=(_BACKEND.parent / ".env", _BACKEND / ".env"), extra="ignore",
                                      frozen=True, populate_by_name=True)

    # "local" = in-memory database + fake upload/transcode (for development and tests).
    # "gcp"   = Firestore + Cloud Storage + Transcoder API.
    mode: Literal["local", "gcp"] = Field("local", validation_alias="CRAFTSTREAM_MODE")
    gcp_project: str = ""
    gcp_region: str = "asia-south1"
    upload_bucket: str = ""   # raw artisan uploads (private)
    media_bucket: str = ""    # HLS output (public read)
    cors_origins: str = "*"
    log_level: str = "INFO"
    # /internal/* callers (gcp mode): the OIDC audience (our Cloud Run URL) and the service account(s)
    # Eventarc and Pub/Sub sign their tokens as, comma-separated.
    internal_audience: str = ""
    internal_invokers: str = ""
    transcode_topic: str = ""   # Pub/Sub topic id the Transcoder publishes job results to

    @model_validator(mode="after")
    def _gcp_needs_resources(self) -> Settings:
        if self.mode == "gcp":
            needed = ("gcp_project", "upload_bucket", "media_bucket", "internal_audience", "internal_invokers",
                      "transcode_topic")
            missing = [k for k in needed if not getattr(self, k)]
            if missing:
                raise ValueError(f"CRAFTSTREAM_MODE=gcp needs {', '.join(m.upper() for m in missing)}")
        return self

    @property
    def internal_invoker_set(self) -> set[str]:
        return {e.strip() for e in self.internal_invokers.split(",") if e.strip()}

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
