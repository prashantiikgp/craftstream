"""Shape of config/media/ingest.yml: how an upload is measured before it is transcoded."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class IngestRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    probe_timeout_seconds: int = Field(gt=0)
    error_text_max_chars: int = Field(gt=0)
