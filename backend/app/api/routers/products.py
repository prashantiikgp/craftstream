"""Catalog endpoints: create a listing, search, product details, tags."""

from __future__ import annotations

from fastapi import APIRouter, Query, Request

from app.api.deps import CatalogDep, MediaDep
from app.generated.models import Product, ProductCreate, ProductPage, TagList, UploadTicket

router = APIRouter()


@router.post("/products", response_model=UploadTicket, status_code=201)
def create_product(body: ProductCreate, request: Request, catalog: CatalogDep, media: MediaDep) -> UploadTicket:
    product = catalog.create_listing(body)
    return media.upload_ticket(product, origin=request.headers.get("origin"), api_base_url=str(request.base_url))


@router.get("/products", response_model=ProductPage, status_code=200)
def list_products(
    catalog: CatalogDep,
    q: str | None = Query(None, max_length=200),
    tag: str | None = Query(None, max_length=50),
    cursor: str | None = Query(None, max_length=100),
    limit: int | None = Query(None, ge=1),
) -> ProductPage:
    return catalog.search(q=q, tag=tag, cursor=cursor, limit=limit)


@router.get("/products/{product_id}", response_model=Product, status_code=200)
def get_product(product_id: str, catalog: CatalogDep) -> Product:
    return catalog.get(product_id)


@router.get("/tags", response_model=TagList, status_code=200)
def list_tags(catalog: CatalogDep) -> TagList:
    return catalog.tags()
