"""Order endpoints. The buyer flow ends at placing one; a device reads its orders back by id."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import OrdersDep
from app.generated.models import Order, OrderCreate

router = APIRouter()


@router.post("/orders", response_model=Order, status_code=201)
def create_order(body: OrderCreate, orders: OrdersDep) -> Order:
    return orders.place(body)


@router.get("/orders/{order_id}", response_model=Order, status_code=200)
def get_order(order_id: str, orders: OrdersDep) -> Order:
    return orders.get(order_id)
