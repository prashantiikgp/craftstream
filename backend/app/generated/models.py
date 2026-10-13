"""GENERATED FROM specs/ BY tools/codegen.py. DO NOT EDIT BY HAND."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class Order(BaseModel):
    """A buyer's order for one product."""

    id: str = Field(...)
    product_id: str = Field(...)
    buyer_name: str = Field(..., min_length=2, max_length=80)
    quantity: int = Field(default=1, ge=1, le=20)
    total: float = Field(...)
    status: Literal['placed'] = Field(default='placed')
    created_at: datetime = Field(...)


class OrderCreate(BaseModel):
    """Body for creating a Order (server-set fields excluded)."""

    product_id: str = Field(...)
    buyer_name: str = Field(..., min_length=2, max_length=80)
    quantity: int = Field(default=1, ge=1, le=20)


class Product(BaseModel):
    """A handmade product listed by an artisan, with a process video."""

    id: str = Field(...)
    title: str = Field(..., min_length=3, max_length=120)
    description: str = Field(..., max_length=5000)
    price: float = Field(..., ge=0.01)
    currency: Literal['INR', 'USD'] = Field(default='INR')
    tags: list[str] = Field(default_factory=list, max_length=10)
    artisan_name: str = Field(..., max_length=80)
    video_status: Literal['awaiting_upload', 'processing', 'ready', 'failed'] = Field(default='awaiting_upload')
    hls_url: str | None = Field(default=None)
    thumbnail_url: str | None = Field(default=None)
    created_at: datetime = Field(...)


class ProductCreate(BaseModel):
    """Body for creating a Product (server-set fields excluded)."""

    title: str = Field(..., min_length=3, max_length=120)
    description: str = Field(..., max_length=5000)
    price: float = Field(..., ge=0.01)
    currency: Literal['INR', 'USD'] = Field(default='INR')
    tags: list[str] = Field(default_factory=list, max_length=10)
    artisan_name: str = Field(..., max_length=80)


class UploadTicket(BaseModel):
    product: Product
    upload_url: str
    upload_method: str
