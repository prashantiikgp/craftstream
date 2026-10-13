"""Load config/catalog/search.yml, validated by SearchRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.catalog.search_schema import SearchRules


@lru_cache(maxsize=1)
def load_search_rules() -> SearchRules:
    return load_yaml("catalog/search.yml", SearchRules)
