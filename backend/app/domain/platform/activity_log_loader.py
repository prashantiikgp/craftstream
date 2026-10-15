"""Load config/platform/activity_log.yml, validated by ActivityLogRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.platform.activity_log_schema import ActivityLogRules


@lru_cache(maxsize=1)
def load_activity_log_rules() -> ActivityLogRules:
    return load_yaml("platform/activity_log.yml", ActivityLogRules)
