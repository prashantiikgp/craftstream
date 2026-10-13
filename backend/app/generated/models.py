"""GENERATED FROM models/ BY tools/codegen.py. DO NOT EDIT BY HAND."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ErrorResponse(BaseModel):
    """The body of every error response."""

    code: str = Field(..., description='machine-readable, e.g. not_found, validation_error, unsupported_media_type')
    message: str = Field(..., description='human-readable summary')
    details: list[str] = Field(default_factory=list, description='one entry per problem, e.g. "body.price - Input should be greater than or equal to 0.01"')


class Order(BaseModel):
    """A buyer's order for one product."""

    id: str = Field(...)
    product_id: str = Field(...)
    buyer_name: str = Field(..., min_length=2, max_length=80)
    quantity: int = Field(default=1, ge=1, le=20)
    total: float = Field(..., description='unit price x quantity, rounded per orders/order_rules.yml')
    currency: Literal['INR', 'USD'] = Field(..., description='copied from the product')
    status: Literal['placed'] = Field(default='placed')
    created_at: datetime = Field(...)


class OrderCreate(BaseModel):
    """Request body to create a new Order (server-set fields excluded)."""

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
    """Request body to create a new Product (server-set fields excluded)."""

    title: str = Field(..., min_length=3, max_length=120)
    description: str = Field(..., max_length=5000)
    price: float = Field(..., ge=0.01)
    currency: Literal['INR', 'USD'] = Field(default='INR')
    tags: list[str] = Field(default_factory=list, max_length=10)
    artisan_name: str = Field(..., max_length=80)


class ProductSummary(BaseModel):
    """A product as shown in search results (no description, no video URL)."""

    id: str = Field(...)
    title: str = Field(...)
    price: float = Field(...)
    currency: Literal['INR', 'USD'] = Field(...)
    tags: list[str] = Field(default_factory=list)
    artisan_name: str = Field(...)
    thumbnail_url: str | None = Field(default=None)


class ProductPage(BaseModel):
    """One page of search results."""

    items: list[ProductSummary] = Field(default_factory=list)
    next_cursor: str | None = Field(default=None, description='opaque; null when there are no more results')


class TagList(BaseModel):
    """Tags that currently have at least one ready product, most used first."""

    tags: list[str] = Field(default_factory=list)


class UploadPolicy(BaseModel):
    """What the app must check before it starts an upload."""

    max_duration_seconds: int = Field(..., ge=1)
    allowed_mime_types: list[str] = Field(default_factory=list)
    chunk_size_bytes: int = Field(..., ge=262144)


class UploadTicket(BaseModel):
    """A new listing plus where and how to upload its video."""

    product: Product = Field(...)
    upload_url: str = Field(..., description='GCS resumable-upload session URL (a local fake in local mode)')
    upload_method: Literal['PUT'] = Field(...)
    chunk_size_bytes: int = Field(..., ge=262144, description='send the file in chunks of this size (a multiple of 256 KiB, as GCS requires)')
