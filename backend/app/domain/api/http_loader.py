"""Load config/api/http.yml, validated by HttpRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.api.http_schema import HttpRules


@lru_cache(maxsize=1)
def load_http_rules() -> HttpRules:
    return load_yaml("api/http.yml", HttpRules)
