"""Where products and orders are stored.

`InMemoryRepo` is used locally and in tests. `FirestoreRepo` is the GCP version;
both expose the same methods, so the API code doesn't care which one runs.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Protocol

from app.generated.models import Order, Product


def new_id() -> str:
    return uuid.uuid4().hex[:12]


def now() -> datetime:
    return datetime.now(UTC)


class Repo(Protocol):
    def save_product(self, p: Product) -> None: ...
    def get_product(self, product_id: str) -> Product | None: ...
    def list_products(self) -> list[Product]: ...
    def save_order(self, o: Order) -> None: ...


class InMemoryRepo:
    def __init__(self) -> None:
        self.products: dict[str, Product] = {}
        self.orders: dict[str, Order] = {}

    def save_product(self, p: Product) -> None:
        self.products[p.id] = p

    def get_product(self, product_id: str) -> Product | None:
        return self.products.get(product_id)

    def list_products(self) -> list[Product]:
        return sorted(self.products.values(), key=lambda p: p.created_at, reverse=True)

    def save_order(self, o: Order) -> None:
        self.orders[o.id] = o


class FirestoreRepo:
    """Firestore-backed repo. Collections: `products`, `orders`."""

    def __init__(self, project: str) -> None:
        from google.cloud import firestore  # imported lazily so local mode needs no GCP libs

        self.db = firestore.Client(project=project)

    def save_product(self, p: Product) -> None:
        data = p.model_dump()
        data["keywords"] = sorted(search_tokens(p))  # stored for simple keyword search
        self.db.collection("products").document(p.id).set(data)

    def get_product(self, product_id: str) -> Product | None:
        doc = self.db.collection("products").document(product_id).get()
        return Product(**doc.to_dict()) if doc.exists else None

    def list_products(self) -> list[Product]:
        docs = self.db.collection("products").order_by("created_at", direction="DESCENDING").limit(200).stream()
        return [Product(**d.to_dict()) for d in docs]

    def save_order(self, o: Order) -> None:
        self.db.collection("orders").document(o.id).set(o.model_dump())


def search_tokens(p: Product) -> set[str]:
    text = f"{p.title} {p.description} {' '.join(p.tags)}".lower()
    return {w.strip(".,!?;:()\"'") for w in text.split() if len(w) > 1}
