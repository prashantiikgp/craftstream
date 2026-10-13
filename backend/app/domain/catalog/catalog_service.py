"""Catalog: create listings, search ready products, list tags.

Search matching and paging still live here as plain functions; B2 moves the rules into
config/catalog/search.yml + search_schema / search_loader / search_engine.
"""

from __future__ import annotations

import logging
from collections import Counter

from app.core.errors import NotFound
from app.core.ids import new_id, now
from app.db.repositories.product_repo import ProductRepo
from app.generated.models import Product, ProductCreate, ProductPage, ProductSummary, TagList

log = logging.getLogger(__name__)

DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE = 20, 50  # -> catalog/search.yml in B2


def _tokens(p: Product) -> set[str]:  # -> search_engine in B2
    text = f"{p.title} {p.description} {' '.join(p.tags)}".lower()
    return {w.strip(".,!?;:()\"'") for w in text.split() if len(w) > 1}


class CatalogService:
    def __init__(self, products: ProductRepo) -> None:
        self._products = products

    def create_listing(self, body: ProductCreate) -> Product:
        product = Product(id=new_id(), created_at=now(), **body.model_dump())
        self._products.save(product, keywords=sorted(_tokens(product)))
        log.info("listing created", extra={"product_id": product.id})
        return product

    def get(self, product_id: str) -> Product:
        product = self._products.get(product_id)
        if product is None:
            raise NotFound(f"Product {product_id} not found")
        return product

    def search(self, q: str | None, tag: str | None, cursor: str | None, limit: int | None) -> ProductPage:
        limit = min(limit or DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE)
        results = self._products.list_ready()
        if tag:
            results = [p for p in results if tag.lower() in (t.lower() for t in p.tags)]
        if q:
            words = q.lower().split()
            results = [p for p in results if all(any(tok.startswith(w) for tok in _tokens(p)) for w in words)]
        if cursor:
            ids = [p.id for p in results]
            results = results[ids.index(cursor) + 1:] if cursor in ids else []
        page = results[:limit]
        next_cursor = page[-1].id if len(results) > limit else None
        fields = set(ProductSummary.model_fields)
        return ProductPage(items=[ProductSummary(**p.model_dump(include=fields)) for p in page],
                           next_cursor=next_cursor)

    def tags(self) -> TagList:
        counts = Counter(t.lower() for p in self._products.list_ready() for t in p.tags)
        return TagList(tags=[t for t, _ in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))])
