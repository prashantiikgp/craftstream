"""Logging: one JSON object per line in GCP mode (Cloud Logging parses `severity` and fields), plain text locally.
Which format each mode uses, and the logger tree to configure, come from config/app/app.yml.

    log = logging.getLogger(__name__)
    log.info("transcode submitted", extra={"product_id": pid, "job": name})
"""

from __future__ import annotations

import json
import logging
import sys

from app.domain.app import app_engine

_STANDARD_ATTRS = set(vars(logging.LogRecord("", 0, "", 0, "", None, None))) | {"message", "asctime"}


class CloudJsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        entry = {
            "severity": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            **{k: v for k, v in vars(record).items() if k not in _STANDARD_ATTRS},
        }
        if record.exc_info:
            entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(entry, default=str)


class PlainFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        extras = {k: v for k, v in vars(record).items() if k not in _STANDARD_ATTRS}
        line = f"{record.levelname:<7} {record.name}: {record.getMessage()}"
        return line + (f"  {extras}" if extras else "")


FORMATTERS: dict[str, type[logging.Formatter]] = {"json": CloudJsonFormatter, "plain": PlainFormatter}


def configure_logging(mode: str, level: str | None = None) -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(FORMATTERS[app_engine.log_format(mode)]())
    root = logging.getLogger(app_engine.logger_name())
    level = level or app_engine.setting_defaults().log_level
    root.handlers[:] = [handler]
    root.setLevel(level.upper())
    root.propagate = False
