"""Shape of config/catalog/listing.yml: record ids, tag clean-up and order, and Firestore storage."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class TagRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    lowercase: bool
    collapse_spaces: bool
    order: Literal["most_used", "alphabetical"]


class Collections(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    products: str = Field(min_length=1)
    orders: str = Field(min_length=1)


class ListingRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id_length: int = Field(ge=8, le=32)  # a UUID has 32 hex characters
    tags: TagRules
    search_candidate_limit: int = Field(gt=0)
    collections: Collections
