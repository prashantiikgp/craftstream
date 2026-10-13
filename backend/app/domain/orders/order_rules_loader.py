"""Load config/orders/order_rules.yml, validated by OrderRules."""

from __future__ import annotations

from functools import lru_cache

from app.core.yaml_loader import load_yaml
from app.schemas.orders.order_rules_schema import OrderRules


@lru_cache(maxsize=1)
def load_order_rules() -> OrderRules:
    return load_yaml("orders/order_rules.yml", OrderRules)
