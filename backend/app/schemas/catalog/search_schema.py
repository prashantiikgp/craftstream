"""Shape of config/catalog/search.yml: how buyers find products."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class PageSize(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    default: int = Field(gt=0)
    max: int = Field(gt=0)

    @model_validator(mode="after")
    def _default_within_max(self) -> PageSize:
        if self.default > self.max:
            raise ValueError("page_size.default must not exceed page_size.max")
        return self


class SearchRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    searchable_fields: list[Literal["title", "description", "tags", "artisan_name"]] = Field(min_length=1)
    min_token_length: int = Field(ge=1)
    stopwords: list[str] = Field(default_factory=list)
    prefix_match: bool
    min_prefix_length: int = Field(ge=1)
    max_query_terms: int = Field(ge=1)
    page_size: PageSize
