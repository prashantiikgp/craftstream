"""Shape of config/api/http.yml: API title and version, error codes and statuses, CORS and compression."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, model_validator


class DefaultError(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    code: str = Field(min_length=1)
    message: str = Field(min_length=1)


class ErrorRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    status: dict[str, int] = Field(min_length=1)
    unlisted_status_code: str = Field(min_length=1)
    validation: DefaultError
    internal: DefaultError

    @model_validator(mode="after")
    def _codes_are_listed(self) -> ErrorRules:
        bad = {c: s for c, s in self.status.items() if not 400 <= s <= 599}
        if bad:
            raise ValueError(f"error statuses must be 4xx or 5xx: {bad}")
        for name, d in (("validation", self.validation), ("internal", self.internal)):
            if d.code not in self.status:
                raise ValueError(f"errors.{name}.code {d.code!r} is not in errors.status")
        return self


class CorsRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    allow_methods: list[str] = Field(min_length=1)
    allow_headers: list[str] = Field(min_length=1)
    expose_headers: list[str] = Field(default_factory=list)


class HttpRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    title: str = Field(min_length=1)
    version: str = Field(min_length=1)
    errors: ErrorRules
    cors: CorsRules
    gzip_minimum_bytes: int = Field(ge=0)
