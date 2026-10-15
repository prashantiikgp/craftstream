"""Shape of config/app/app.yml: the default settings, the settings each mode requires, and the log format."""

from __future__ import annotations

from typing import Literal, get_args

from pydantic import BaseModel, ConfigDict, Field, field_validator

Mode = Literal["local", "gcp"]
LogFormat = Literal["json", "plain"]
LogLevel = Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]


class SettingDefaults(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    mode: Mode
    gcp_region: str = Field(min_length=1)
    cors_origins: str = Field(min_length=1)
    log_level: LogLevel


class LoggingRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    logger: str = Field(min_length=1)
    format: dict[Mode, LogFormat]

    @field_validator("format")
    @classmethod
    def _every_mode(cls, v: dict[Mode, LogFormat]) -> dict[Mode, LogFormat]:
        missing = set(get_args(Mode)) - set(v)
        if missing:
            raise ValueError(f"no log format for mode(s) {sorted(missing)}")
        return v


class AppRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    defaults: SettingDefaults
    required: dict[Mode, list[str]] = Field(default_factory=dict)
    logging: LoggingRules
