"""Catalog: create listings, search listed products, list tags. Search rules come from search_engine;
which video state is listed comes from the media video_lifecycle_engine."""

from __future__ import annotations

import logging
from collections import Counter

from app.core.errors import NotFound
from app.core.ids import new_id, now
from app.db.repositories.product_repo import ProductRepo
from app.domain.catalog import search_engine
from app.domain.media import video_lifecycle_engine as lifecycle
from app.generated.models import Product, ProductCreate, ProductPage, ProductSummary, TagList

log = logging.getLogger(__name__)

_SUMMARY_FIELDS = set(ProductSummary.model_fields)


def _keywords(p: Product) -> list[str]:
    return search_engine.index_terms(
        {"title": p.title, "description": p.description, "tags": p.tags, "artisan_name": p.artisan_name})


class CatalogService:
    def __init__(self, products: ProductRepo) -> None:
        self._products = products

    def create_listing(self, body: ProductCreate) -> Product:
        data = body.model_dump()
        data["tags"] = list(dict.fromkeys(search_engine.normalize_tag(t) for t in data["tags"] if t.strip()))
        product = Product(id=new_id(), created_at=now(), video_status=lifecycle.initial_state(), **data)
        self._products.save(product, keywords=_keywords(product))
        log.info("listing created", extra={"product_id": product.id})
        return product

    def get(self, product_id: str) -> Product:
        product = self._products.get(product_id)
        if product is None:
            raise NotFound(f"Product {product_id} not found")
        return product

    def search(self, q: str | None, tag: str | None, cursor: str | None, limit: int | None) -> ProductPage:
        terms = search_engine.query_terms(q)
        tag_term = search_engine.tag_term(tag)
        if tag_term:
            terms.append(tag_term)

        # The database narrows by one term; the engine checks the rest.
        candidates = self._products.list_with_status(lifecycle.listable_state(), contains=search_engine.most_selective(terms))
        results = [p for p in candidates if search_engine.matches(_keywords(p), terms)]

        if cursor:
            ids = [p.id for p in results]
            results = results[ids.index(cursor) + 1:] if cursor in ids else []
        size = search_engine.page_size(limit)
        page = results[:size]
        return ProductPage(items=[ProductSummary(**p.model_dump(include=_SUMMARY_FIELDS)) for p in page],
                           next_cursor=page[-1].id if len(results) > size else None)

    def tags(self) -> TagList:
        counts = Counter(t for p in self._products.list_with_status(lifecycle.listable_state()) for t in p.tags)
        return TagList(tags=[t for t, _ in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))])
