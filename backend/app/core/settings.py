"""Settings, read from environment variables (see .env.example). Validated at startup.

Defaults, and the settings each mode requires, come from config/app/app.yml; an environment variable (or .env)
overrides every default. Per-environment values default to "" (unset).
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

from app.domain.app import app_engine
from app.schemas.app.app_schema import Mode

_BACKEND = Path(__file__).resolve().parents[2]
_DEFAULTS = app_engine.setting_defaults()


class Settings(BaseSettings):
    # Real environment variables win over .env files; .env at the repo root or in backend/ (both gitignored).
    model_config = SettingsConfigDict(env_file=(_BACKEND.parent / ".env", _BACKEND / ".env"), extra="ignore",
                                      frozen=True, populate_by_name=True)

    # "local" = in-memory database + fake upload/transcode (for development and tests).
    # "gcp"   = Firestore + Cloud Storage + Transcoder API.
    mode: Mode = Field(_DEFAULTS.mode, validation_alias="CRAFTSTREAM_MODE")
    gcp_project: str = ""
    gcp_region: str = _DEFAULTS.gcp_region
    upload_bucket: str = ""   # raw artisan uploads (private)
    media_bucket: str = ""    # HLS output (public read)
    cors_origins: str = _DEFAULTS.cors_origins
    log_level: str = _DEFAULTS.log_level
    # /internal/* callers (gcp mode): the OIDC audiences and the service account(s) Eventarc and Pub/Sub sign
    # their tokens as, both comma-separated. Audiences are our Cloud Run URLs: Eventarc mints tokens for the
    # service's hash URL (…-<hash>-el.a.run.app), our Pub/Sub push for the deterministic one.
    internal_audience: str = ""
    internal_invokers: str = ""
    transcode_topic: str = ""   # Pub/Sub topic id the Transcoder publishes job results to

    @model_validator(mode="after")
    def _mode_has_what_it_needs(self) -> Settings:
        missing = app_engine.missing_settings(self.mode, self.model_dump())
        if missing:
            raise ValueError(f"CRAFTSTREAM_MODE={self.mode} needs {', '.join(m.upper() for m in missing)}")
        return self

    @property
    def internal_audience_list(self) -> list[str]:
        return [a.strip() for a in self.internal_audience.split(",") if a.strip()]

    @property
    def internal_invoker_set(self) -> set[str]:
        return {e.strip() for e in self.internal_invokers.split(",") if e.strip()}

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
