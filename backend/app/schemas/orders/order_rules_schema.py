"""Shape of config/orders/order_rules.yml: what it takes to place an order and how the total is computed."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class TotalRounding(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    decimals: int = Field(ge=0, le=4)
    mode: Literal["half_up", "half_even"]


class OrderRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    require_ready_video: bool
    total_rounding: TotalRounding
