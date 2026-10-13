"""Logging: one JSON object per line in GCP mode (Cloud Logging parses `severity` and fields), plain text locally.

    log = logging.getLogger(__name__)
    log.info("transcode submitted", extra={"product_id": pid, "job": name})
"""

from __future__ import annotations

import json
import logging
import sys

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


def configure_logging(mode: str, level: str = "INFO") -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(CloudJsonFormatter() if mode == "gcp" else PlainFormatter())
    root = logging.getLogger("app")
    root.handlers[:] = [handler]
    root.setLevel(level.upper())
    root.propagate = False
