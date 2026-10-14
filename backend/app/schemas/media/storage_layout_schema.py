"""Shape of config/media/storage_layout.yml: object names, URLs and cache headers for video files."""

from __future__ import annotations

import re

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

PRODUCT_ID = "{product_id}"


class ThumbnailName(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    prefix: str = Field(min_length=1)
    suffix: str = Field(min_length=1)


class LocalLayout(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    upload_path: str
    sample_stream: str

    @field_validator("upload_path")
    @classmethod
    def _names_the_product(cls, v: str) -> str:
        if not v.startswith("/") or PRODUCT_ID not in v:
            raise ValueError(f"must start with / and contain {PRODUCT_ID}")
        return v


class StorageLayoutRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    raw_object: str
    raw_object_pattern: str
    hls_prefix: str
    manifest: str = Field(min_length=1)
    thumbnail: ThumbnailName
    object_url: str
    gcs_uri: str
    hls_cache_control: str = Field(min_length=1)
    job_label: str = Field(min_length=1)
    local: LocalLayout

    @field_validator("raw_object", "hls_prefix")
    @classmethod
    def _per_product(cls, v: str) -> str:
        if PRODUCT_ID not in v:
            raise ValueError(f"must contain {PRODUCT_ID}")
        return v

    @field_validator("hls_prefix")
    @classmethod
    def _is_a_folder(cls, v: str) -> str:
        if not v.endswith("/"):
            raise ValueError("must end with /")
        return v

    @field_validator("object_url", "gcs_uri")
    @classmethod
    def _bucket_and_object(cls, v: str) -> str:
        if "{bucket}" not in v or "{object}" not in v:
            raise ValueError("must contain {bucket} and {object}")
        return v

    @model_validator(mode="after")
    def _pattern_finds_raw_objects(self) -> StorageLayoutRules:
        rx = re.compile(self.raw_object_pattern)
        if "product_id" not in rx.groupindex:
            raise ValueError("raw_object_pattern needs a (?P<product_id>...) group")
        m = rx.match(self.raw_object.format(product_id="abc123"))
        if not m or m["product_id"] != "abc123":
            raise ValueError("raw_object_pattern must match raw_object and capture the product id")
        return self
