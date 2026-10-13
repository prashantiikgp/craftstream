"""Load config/media/upload_policy.yml, validated by UploadPolicyRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.media.upload_policy_schema import UploadPolicyRules


@lru_cache(maxsize=1)
def load_upload_policy_rules() -> UploadPolicyRules:
    return load_yaml("media/upload_policy.yml", UploadPolicyRules)
