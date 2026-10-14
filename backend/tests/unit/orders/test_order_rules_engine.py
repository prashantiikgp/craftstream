"""Order rules: who can order, and totals computed with Decimal rounding."""

from app.domain.orders import order_rules_engine as ore
from app.domain.orders.order_rules_loader import load_order_rules
from app.schemas.orders.order_rules_schema import TotalRounding


def test_only_ready_products_can_be_ordered():
    assert ore.can_order(video_orderable=True)
    assert not ore.can_order(video_orderable=False)
    relaxed = load_order_rules().model_copy(update={"require_ready_video": False})
    assert ore.can_order(video_orderable=False, rules=relaxed)


def test_total_avoids_float_errors():
    assert ore.total(0.1, 3) == 0.3          # float math gives 0.30000000000000004
    assert ore.total(19.99, 3) == 59.97


def test_rounding_modes():
    rules = load_order_rules()
    half_even = rules.model_copy(update={"total_rounding": TotalRounding(decimals=2, mode="half_even")})
    assert ore.total(0.125, 1) == 0.13       # half_up (the configured default)
    assert ore.total(0.125, 1, half_even) == 0.12
