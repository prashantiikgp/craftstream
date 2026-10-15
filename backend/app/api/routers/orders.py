"""Order endpoints. The buyer flow ends at placing one; a device reads its orders back by id.
Routes: models/endpoints.yml."""

from __future__ import annotations

from app.api.deps import OrdersDep
from app.api.endpoints import EndpointHandlers
from app.generated.models import Order, OrderCreate

endpoints = EndpointHandlers()


@endpoints.handler("createOrder")
def create_order(body: OrderCreate, orders: OrdersDep) -> Order:
    return orders.place(body)


@endpoints.handler("getOrder")
def get_order(order_id: str, orders: OrdersDep) -> Order:
    return orders.get(order_id)
