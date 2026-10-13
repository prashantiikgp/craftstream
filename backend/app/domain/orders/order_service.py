"""Orders: validate, compute the total, store. The buyer flow ends here (no shipping or payment).

Total rounding moves to config/orders/order_rules.yml + order_rules_engine in B2.
"""

from __future__ import annotations

import logging

from app.core.errors import Conflict, NotFound
from app.core.ids import new_id, now
from app.db.repositories.order_repo import OrderRepo
from app.db.repositories.product_repo import ProductRepo
from app.generated.models import Order, OrderCreate

log = logging.getLogger(__name__)


class OrderService:
    def __init__(self, products: ProductRepo, orders: OrderRepo) -> None:
        self._products, self._orders = products, orders

    def place(self, body: OrderCreate) -> Order:
        product = self._products.get(body.product_id)
        if product is None:
            raise NotFound(f"Product {body.product_id} not found")
        if product.video_status != "ready":
            raise Conflict("This product is not available to order yet.", code="product_not_ready")
        order = Order(id=new_id(), created_at=now(), total=round(product.price * body.quantity, 2),
                      currency=product.currency, **body.model_dump())
        self._orders.save(order)
        log.info("order placed", extra={"order_id": order.id, "product_id": product.id})
        return order
