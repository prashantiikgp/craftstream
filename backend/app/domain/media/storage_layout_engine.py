"""Object names and URLs for video files. Pure logic over StorageLayoutRules (bucket names are passed in).

    raw_object(abc)              -> raw/abc/source              (the artisan's upload)
    manifest_object(abc)         -> hls/abc/manifest.m3u8       (the Transcoder's output)
    object_url(bucket, name)     -> https://storage.googleapis.com/<bucket>/<name>
"""

from __future__ import annotations

import re
from functools import lru_cache

from app.domain.media.storage_layout_loader import load_storage_layout_rules
from app.schemas.media.storage_layout_schema import StorageLayoutRules


def _rules(rules: StorageLayoutRules | None) -> StorageLayoutRules:
    return rules or load_storage_layout_rules()


@lru_cache(maxsize=4)
def _pattern(pattern: str) -> re.Pattern[str]:
    return re.compile(pattern)


def raw_object(product_id: str, rules: StorageLayoutRules | None = None) -> str:
    return _rules(rules).raw_object.format(product_id=product_id)


def product_id_from_object(object_name: str, rules: StorageLayoutRules | None = None) -> str | None:
    """The product a raw upload belongs to; None for any other object in the bucket."""
    m = _pattern(_rules(rules).raw_object_pattern).match(object_name)
    return m["product_id"] if m else None


def hls_prefix(product_id: str, rules: StorageLayoutRules | None = None) -> str:
    return _rules(rules).hls_prefix.format(product_id=product_id)


def manifest_name(rules: StorageLayoutRules | None = None) -> str:
    return _rules(rules).manifest


def manifest_object(product_id: str, rules: StorageLayoutRules | None = None) -> str:
    r = _rules(rules)
    return hls_prefix(product_id, r) + r.manifest


def thumbnail_prefix(rules: StorageLayoutRules | None = None) -> str:
    return _rules(rules).thumbnail.prefix


def thumbnail_object(product_id: str, rules: StorageLayoutRules | None = None) -> str:
    r = _rules(rules)
    return hls_prefix(product_id, r) + r.thumbnail.prefix + r.thumbnail.suffix


def object_url(bucket: str, object_name: str, rules: StorageLayoutRules | None = None) -> str:
    return _rules(rules).object_url.format(bucket=bucket, object=object_name)


def gcs_uri(bucket: str, object_name: str, rules: StorageLayoutRules | None = None) -> str:
    return _rules(rules).gcs_uri.format(bucket=bucket, object=object_name)


def hls_cache_control(rules: StorageLayoutRules | None = None) -> str:
    return _rules(rules).hls_cache_control


def job_label(rules: StorageLayoutRules | None = None) -> str:
    return _rules(rules).job_label


def local_upload_path(product_id: str, rules: StorageLayoutRules | None = None) -> str:
    return _rules(rules).local.upload_path.format(product_id=product_id)


def local_upload_route(rules: StorageLayoutRules | None = None) -> str:
    """The route the API serves the fake upload target on (the path template itself)."""
    return _rules(rules).local.upload_path


def local_sample_stream(rules: StorageLayoutRules | None = None) -> str:
    return _rules(rules).local.sample_stream
