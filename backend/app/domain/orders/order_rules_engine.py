"""Order rules: can this product be ordered, and what's the total. Pure logic over OrderRules."""

from __future__ import annotations

from decimal import ROUND_HALF_EVEN, ROUND_HALF_UP, Decimal

from app.domain.orders.order_rules_loader import load_order_rules
from app.schemas.orders.order_rules_schema import OrderRules

_MODES = {"half_up": ROUND_HALF_UP, "half_even": ROUND_HALF_EVEN}


def _rules(rules: OrderRules | None) -> OrderRules:
    return rules or load_order_rules()


def can_order(video_orderable: bool, rules: OrderRules | None = None) -> bool:
    """`video_orderable`: the video is in the orderable state (media video_lifecycle_engine.is_orderable)."""
    return video_orderable or not _rules(rules).require_ready_video


def total(unit_price: float, quantity: int, rules: OrderRules | None = None) -> float:
    """unit price x quantity, rounded per the rules. Decimal math (from the price's decimal text), not float."""
    r = _rules(rules).total_rounding
    exact = Decimal(str(unit_price)) * quantity
    return float(exact.quantize(Decimal(1).scaleb(-r.decimals), rounding=_MODES[r.mode]))
