"""Load config/media/ingest.yml, validated by IngestRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.media.ingest_schema import IngestRules


@lru_cache(maxsize=1)
def load_ingest_rules() -> IngestRules:
    return load_yaml("media/ingest.yml", IngestRules)
