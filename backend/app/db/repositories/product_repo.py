"""Where products are stored. Pure storage: no business rules (search matching lives in the catalog domain).

`InMemoryProductRepo` is used locally and in tests; `FirestoreProductRepo` is the GCP version.
Both store the search `keywords` (from catalog search_engine) and can narrow a listing to one keyword.
"""

from __future__ import annotations

from typing import Literal, Protocol

from app.generated.models import Product

VideoStatus = Literal["awaiting_upload", "processing", "ready", "failed"]


class ProductRepo(Protocol):
    def save(self, product: Product, keywords: list[str]) -> None: ...
    def get(self, product_id: str) -> Product | None: ...
    def list_ready(self, contains: str | None = None) -> list[Product]: ...
    def update_video(self, product_id: str, status: VideoStatus, hls_url: str | None = None,
                     thumbnail_url: str | None = None) -> None: ...


class InMemoryProductRepo:
    def __init__(self) -> None:
        self._products: dict[str, Product] = {}
        self.keywords: dict[str, list[str]] = {}

    def save(self, product: Product, keywords: list[str]) -> None:
        self._products[product.id] = product.model_copy(deep=True)
        self.keywords[product.id] = keywords

    def get(self, product_id: str) -> Product | None:
        p = self._products.get(product_id)
        return p.model_copy(deep=True) if p else None

    def list_ready(self, contains: str | None = None) -> list[Product]:
        ready = [p for p in self._products.values()
                 if p.video_status == "ready" and (contains is None or contains in self.keywords.get(p.id, ()))]
        return [p.model_copy(deep=True) for p in sorted(ready, key=lambda p: (p.created_at, p.id), reverse=True)]

    def update_video(self, product_id: str, status: VideoStatus, hls_url: str | None = None,
                     thumbnail_url: str | None = None) -> None:
        p = self._products[product_id]
        self._products[product_id] = p.model_copy(
            update={"video_status": status, "hls_url": hls_url, "thumbnail_url": thumbnail_url})


class FirestoreProductRepo:
    """Collection `products`; each document is the Product plus a `keywords` array."""

    LIST_LIMIT = 500  # candidates per search; the rest of the matching and paging happens in the service

    def __init__(self, project: str) -> None:
        from google.cloud import firestore  # imported lazily so local mode needs no GCP libs

        self._db = firestore.Client(project=project)
        self._col = self._db.collection("products")

    def save(self, product: Product, keywords: list[str]) -> None:
        self._col.document(product.id).set({**product.model_dump(), "keywords": keywords})

    def get(self, product_id: str) -> Product | None:
        doc = self._col.document(product_id).get()
        return _to_product(doc.to_dict()) if doc.exists else None

    def list_ready(self, contains: str | None = None) -> list[Product]:
        from google.cloud import firestore
        from google.cloud.firestore_v1.base_query import FieldFilter

        # Needs composite indexes: (video_status, created_at desc) and (video_status, keywords array, created_at desc).
        query = self._col.where(filter=FieldFilter("video_status", "==", "ready"))
        if contains is not None:
            query = query.where(filter=FieldFilter("keywords", "array_contains", contains))
        docs = (query.order_by("created_at", direction=firestore.Query.DESCENDING)
                .limit(self.LIST_LIMIT).stream())
        return [_to_product(d.to_dict()) for d in docs]

    def update_video(self, product_id: str, status: VideoStatus, hls_url: str | None = None,
                     thumbnail_url: str | None = None) -> None:
        # Partial update: never overwrites the listing fields or keywords.
        self._col.document(product_id).update(
            {"video_status": status, "hls_url": hls_url, "thumbnail_url": thumbnail_url})


def _to_product(data: dict) -> Product:
    data.pop("keywords", None)
    return Product(**data)
