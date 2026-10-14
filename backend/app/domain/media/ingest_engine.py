"""Measuring an upload: the ffprobe time limit and how its error text is trimmed. Pure logic over IngestRules."""

from __future__ import annotations

from app.domain.media.ingest_loader import load_ingest_rules
from app.schemas.media.ingest_schema import IngestRules


def _rules(rules: IngestRules | None) -> IngestRules:
    return rules or load_ingest_rules()


def probe_timeout_seconds(rules: IngestRules | None = None) -> int:
    return _rules(rules).probe_timeout_seconds


def error_text(stderr: str, fallback: str, rules: IngestRules | None = None) -> str:
    """The end of a tool's error output (where the reason usually is), or `fallback` if there is none."""
    text = stderr.strip()
    return text[-_rules(rules).error_text_max_chars:] if text else fallback
