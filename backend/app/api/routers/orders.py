"""Order endpoint. The buyer flow ends here."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import OrdersDep
from app.generated.models import Order, OrderCreate

router = APIRouter()


@router.post("/orders", response_model=Order, status_code=201)
def create_order(body: OrderCreate, orders: OrdersDep) -> Order:
    return orders.place(body)
