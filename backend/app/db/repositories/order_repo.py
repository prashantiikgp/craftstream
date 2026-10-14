"""Where orders are stored. `InMemoryOrderRepo` locally and in tests; `FirestoreOrderRepo` on GCP."""

from __future__ import annotations

from typing import Protocol

from app.generated.models import Order


class OrderRepo(Protocol):
    def save(self, order: Order) -> None: ...
    def get(self, order_id: str) -> Order | None: ...


class InMemoryOrderRepo:
    def __init__(self) -> None:
        self._orders: dict[str, Order] = {}

    def save(self, order: Order) -> None:
        self._orders[order.id] = order.model_copy(deep=True)

    def get(self, order_id: str) -> Order | None:
        o = self._orders.get(order_id)
        return o.model_copy(deep=True) if o else None


class FirestoreOrderRepo:
    """The collection name comes from catalog/listing.yml (passed in by api/deps.py)."""

    def __init__(self, project: str, collection: str) -> None:
        from google.cloud import firestore  # imported lazily so local mode needs no GCP libs

        self._col = firestore.Client(project=project).collection(collection)

    def save(self, order: Order) -> None:
        self._col.document(order.id).set(order.model_dump())

    def get(self, order_id: str) -> Order | None:
        doc = self._col.document(order_id).get()
        return Order(**doc.to_dict()) if doc.exists else None
