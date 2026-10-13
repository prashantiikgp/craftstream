"""Upload rules: chunk size, allowed file types and the duration cap. Pure logic over UploadPolicyRules."""

from __future__ import annotations

from app.domain.media.upload_policy_loader import load_upload_policy_rules
from app.schemas.media.upload_policy_schema import UploadPolicyRules


def _rules(rules: UploadPolicyRules | None) -> UploadPolicyRules:
    return rules or load_upload_policy_rules()


def chunk_size_bytes(rules: UploadPolicyRules | None = None) -> int:
    return _rules(rules).chunk_size_kib * 1024


def max_duration_seconds(rules: UploadPolicyRules | None = None) -> int:
    return _rules(rules).max_duration_seconds


def is_allowed_mime_type(mime_type: str, rules: UploadPolicyRules | None = None) -> bool:
    return mime_type.split(";")[0].strip().lower() in _rules(rules).allowed_mime_types


def is_allowed_duration(seconds: float, rules: UploadPolicyRules | None = None) -> bool:
    return 0 < seconds <= _rules(rules).max_duration_seconds
