"""Load config/media/storage_layout.yml, validated by StorageLayoutRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.media.storage_layout_schema import StorageLayoutRules


@lru_cache(maxsize=1)
def load_storage_layout_rules() -> StorageLayoutRules:
    return load_yaml("media/storage_layout.yml", StorageLayoutRules)
