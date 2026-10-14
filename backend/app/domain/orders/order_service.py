"""Orders: validate, compute the total, store. The buyer flow ends here (no shipping or payment).

Rules (who can order, how the total rounds) come from order_rules_engine.
"""

from __future__ import annotations

import logging

from app.core.errors import Conflict, NotFound
from app.core.ids import new_id, now
from app.db.repositories.order_repo import OrderRepo
from app.db.repositories.product_repo import ProductRepo
from app.domain.orders import order_rules_engine
from app.generated.models import Order, OrderCreate

log = logging.getLogger(__name__)


class OrderService:
    def __init__(self, products: ProductRepo, orders: OrderRepo) -> None:
        self._products, self._orders = products, orders

    def place(self, body: OrderCreate) -> Order:
        product = self._products.get(body.product_id)
        if product is None:
            raise NotFound(f"Product {body.product_id} not found")
        if not order_rules_engine.can_order(product.video_status):
            raise Conflict("This product is not available to order yet.", code="product_not_ready")
        order = Order(id=new_id(), created_at=now(), total=order_rules_engine.total(product.price, body.quantity),
                      currency=product.currency, **body.model_dump())
        self._orders.save(order)
        log.info("order placed", extra={"order_id": order.id, "product_id": product.id})
        return order

    def get(self, order_id: str) -> Order:
        order = self._orders.get(order_id)
        if order is None:
            raise NotFound(f"Order {order_id} not found")
        return order
