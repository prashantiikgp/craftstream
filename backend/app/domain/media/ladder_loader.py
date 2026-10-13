"""Load config/media/ladder.yml, validated by LadderRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.media.ladder_schema import LadderRules


@lru_cache(maxsize=1)
def load_ladder_rules() -> LadderRules:
    return load_yaml("media/ladder.yml", LadderRules)
