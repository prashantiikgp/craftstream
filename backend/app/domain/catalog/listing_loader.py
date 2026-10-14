"""Load config/catalog/listing.yml, validated by ListingRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.catalog.listing_schema import ListingRules


@lru_cache(maxsize=1)
def load_listing_rules() -> ListingRules:
    return load_yaml("catalog/listing.yml", ListingRules)
