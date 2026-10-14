"""Load config/platform/events.yml, validated by EventsRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.platform.events_schema import EventsRules


@lru_cache(maxsize=1)
def load_events_rules() -> EventsRules:
    return load_yaml("platform/events.yml", EventsRules)
