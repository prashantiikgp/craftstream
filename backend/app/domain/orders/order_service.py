"""Orders: validate, compute the total, store. The buyer flow ends here (no shipping or payment).

Rules (who can order, how the total rounds) come from order_rules_engine.
"""

from __future__ import annotations

from app.core.errors import Conflict, DomainError, NotFound
from app.core.ids import new_id, now
from app.db.repositories.order_repo import OrderRepo
from app.db.repositories.product_repo import ProductRepo
from app.domain.media import video_lifecycle_engine as lifecycle
from app.domain.orders import order_rules_engine
from app.domain.platform.activity_log_service import ActivityLogService
from app.generated.models import Order, OrderCreate


class OrderService:
    def __init__(self, products: ProductRepo, orders: OrderRepo, activity: ActivityLogService) -> None:
        self._products, self._orders, self._activity = products, orders, activity

    def place(self, body: OrderCreate) -> Order:
        try:
            product = self._products.get(body.product_id)
            if product is None:
                raise NotFound(f"Product {body.product_id} not found")
            if not order_rules_engine.can_order(lifecycle.is_orderable(product.video_status)):
                raise Conflict("This product is not available to order yet.", code="product_not_ready")
        except DomainError as e:
            self._activity.record("order_rejected", product_id=body.product_id, reason=e.code)
            raise
        order = Order(id=new_id(), created_at=now(), total=order_rules_engine.total(product.price, body.quantity),
                      currency=product.currency, **body.model_dump())
        self._orders.save(order)
        # Never the buyer's name: ids and amounts only.
        self._activity.record("order_placed", product_id=product.id, order_id=order.id, quantity=order.quantity,
                              total=order.total, currency=order.currency)
        return order

    def get(self, order_id: str) -> Order:
        order = self._orders.get(order_id)
        if order is None:
            raise NotFound(f"Order {order_id} not found")
        return order
