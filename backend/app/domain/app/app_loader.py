"""Load config/app/app.yml, validated by AppRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.app.app_schema import AppRules


@lru_cache(maxsize=1)
def load_app_rules() -> AppRules:
    return load_yaml("app/app.yml", AppRules)
