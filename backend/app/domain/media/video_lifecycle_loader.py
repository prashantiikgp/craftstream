"""Load config/media/video_lifecycle.yml, validated by VideoLifecycleRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.media.video_lifecycle_schema import VideoLifecycleRules


@lru_cache(maxsize=1)
def load_video_lifecycle_rules() -> VideoLifecycleRules:
    return load_yaml("media/video_lifecycle.yml", VideoLifecycleRules)
