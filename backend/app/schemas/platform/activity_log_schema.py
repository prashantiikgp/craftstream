"""Shape of config/platform/activity_log.yml: where the log is stored, how long it is kept, its limits and the
event catalogue. Levels, groups and sources are the enums of models/log_entry.yml (the generated LogEntry).
"""

from __future__ import annotations

import re
import string
from typing import Annotated

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, model_validator

from app.generated.models import LogDetail, LogEntry

# The enums of LogEntry, so a level, group or source the model doesn't know fails at startup.
Level = LogEntry.model_fields["level"].annotation
Group = LogEntry.model_fields["group"].annotation
Source = LogEntry.model_fields["source"].annotation

_NAME = re.compile(r"[a-z][a-z0-9_]*")
_EVENT_MAX = next(m.max_length for m in LogEntry.model_fields["event"].metadata if hasattr(m, "max_length"))
_KEY_MAX = next(m.max_length for m in LogDetail.model_fields["key"].metadata if hasattr(m, "max_length"))
# Placeholders a message may use besides the event's own detail keys.
ENTRY_FIELDS = ("product_id", "order_id")


def _name(v: str) -> str:
    if not _NAME.fullmatch(v):
        raise ValueError(f"{v!r} must be lower_snake_case")
    return v


Name = Annotated[str, AfterValidator(_name)]


def placeholders(template: str) -> list[str]:
    """The `{name}` fields of a message template (raises ValueError for a malformed template)."""
    return [field for _, field, _, _ in string.Formatter().parse(template) if field is not None]


class EventRule(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    source: Source
    group: Group
    level: Level
    details: list[Annotated[str, Field(min_length=1, max_length=_KEY_MAX)]] = Field(default_factory=list)
    message: str = Field(min_length=1)

    @model_validator(mode="after")
    def _template_uses_known_fields(self) -> EventRule:
        allowed = set(self.details) | set(ENTRY_FIELDS)
        try:
            used = placeholders(self.message)
        except ValueError as e:
            raise ValueError(f"message {self.message!r} is not a valid template: {e}") from e
        unknown = [f for f in used if f not in allowed]
        if unknown:
            raise ValueError(f"message {self.message!r} uses {unknown}; it may use only {sorted(allowed)}")
        if len(set(self.details)) != len(self.details):
            raise ValueError(f"details {self.details} repeat a key")
        return self


class PageSize(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    default: int = Field(ge=1)
    max: int = Field(ge=1)

    @model_validator(mode="after")
    def _default_fits(self) -> PageSize:
        if self.default > self.max:
            raise ValueError("page_size.default must not exceed page_size.max")
        return self


class DetailLimits(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    max_per_entry: int = Field(ge=1)
    max_key_length: int = Field(ge=1)
    max_value_length: int = Field(ge=1)
    float_decimals: int = Field(ge=0)
    missing_value: str = Field(min_length=1)


class Sources(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    server: Source
    client: Source

    @model_validator(mode="after")
    def _different(self) -> Sources:
        if self.server == self.client:
            raise ValueError("sources.server and sources.client must differ")
        return self


class ErrorRule(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    code: Name
    message: str = Field(min_length=1)


class Errors(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    unknown_event: ErrorRule
    not_reportable: ErrorRule
    bad_filter: ErrorRule


class ActivityLogRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    collection: Name
    expire_field: Name
    keep_days: int = Field(ge=1)
    write_timeout_seconds: float = Field(gt=0)
    page_size: PageSize
    details: DetailLimits
    mirror_to_stdout: bool
    sources: Sources
    errors: Errors
    events: dict[Annotated[Name, Field(max_length=_EVENT_MAX)], EventRule] = Field(min_length=1)

    @model_validator(mode="after")
    def _events_fit_the_limits(self) -> ActivityLogRules:
        for name, ev in self.events.items():
            if ev.source not in (self.sources.server, self.sources.client):
                raise ValueError(f"events.{name}.source {ev.source!r} is neither sources.server nor sources.client")
            if len(ev.details) > self.details.max_per_entry:
                raise ValueError(f"events.{name} declares more than details.max_per_entry keys")
            long = [k for k in ev.details if len(k) > self.details.max_key_length]
            if long:
                raise ValueError(f"events.{name}: detail keys longer than details.max_key_length: {long}")
        return self
