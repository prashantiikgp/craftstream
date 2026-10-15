"""Shape of config/platform/events.yml: the GCP callbacks' message formats (routes: models/endpoints.yml)."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class UploadFinalized(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    event_type_header: str = Field(min_length=1)
    accepted_event_types: list[str] = Field(min_length=1)
    object_name_key: str = Field(min_length=1)


class TranscodeResult(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    envelope_keys: list[str] = Field(min_length=1)
    job_key: str = Field(min_length=1)
    job_name_key: str = Field(min_length=1)
    job_state_key: str = Field(min_length=1)


class Messages(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    not_json: str = Field(min_length=1)
    not_an_object: str = Field(min_length=1)
    not_a_job_result: str = Field(min_length=1)


class EventsRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    upload_finalized: UploadFinalized
    transcode_result: TranscodeResult
    messages: Messages
