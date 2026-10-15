"""Catalog endpoints: create a listing, search, product details, tags. Routes: models/endpoints.yml."""

from __future__ import annotations

from fastapi import Request

from app.api.deps import CatalogDep, MediaDep
from app.api.endpoints import EndpointHandlers
from app.generated.models import Product, ProductCreate, ProductPage, TagList, UploadTicket

endpoints = EndpointHandlers()


@endpoints.handler("createProduct")
def create_product(body: ProductCreate, request: Request, catalog: CatalogDep, media: MediaDep) -> UploadTicket:
    product = catalog.create_listing(body)
    return media.upload_ticket(product, origin=request.headers.get("origin"), api_base_url=str(request.base_url))


@endpoints.handler("listProducts")
def list_products(
    catalog: CatalogDep,
    q: str | None = None,
    tag: str | None = None,
    cursor: str | None = None,
    limit: int | None = None,
) -> ProductPage:
    return catalog.search(q=q, tag=tag, cursor=cursor, limit=limit)


@endpoints.handler("getProduct")
def get_product(product_id: str, catalog: CatalogDep) -> Product:
    return catalog.get(product_id)


@endpoints.handler("listTags")
def list_tags(catalog: CatalogDep) -> TagList:
    return catalog.tags()
