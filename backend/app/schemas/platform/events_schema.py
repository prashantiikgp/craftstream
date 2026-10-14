"""Shape of config/platform/events.yml: the GCP callback routes and their message formats."""

from __future__ import annotations

from typing import Annotated

from pydantic import AfterValidator, BaseModel, ConfigDict, Field


def _route(v: str) -> str:
    if not v.startswith("/") or v.endswith("/"):
        raise ValueError("must start with / and not end with /")
    return v


Route = Annotated[str, AfterValidator(_route)]


class UploadFinalized(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    path: Route
    event_type_header: str = Field(min_length=1)
    accepted_event_types: list[str] = Field(min_length=1)
    object_name_key: str = Field(min_length=1)


class TranscodeResult(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    path: Route
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

    internal_prefix: Route
    upload_finalized: UploadFinalized
    transcode_result: TranscodeResult
    messages: Messages
