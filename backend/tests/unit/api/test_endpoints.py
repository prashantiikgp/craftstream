"""api/endpoints.py: a handler must match its endpoint in models/endpoints.yml, or the app does not start."""

from __future__ import annotations

import inspect

import pytest
from fastapi import FastAPI
from fastapi.routing import APIRoute

from app.api.endpoints import EndpointError, EndpointHandlers, mount
from app.core.settings import Settings
from app.generated.api import ENDPOINTS
from app.generated.models import Order, OrderCreate, ProductPage
from app.main import create_app


def test_unknown_or_repeated_names_are_rejected():
    eps = EndpointHandlers()
    with pytest.raises(EndpointError, match="not an endpoint"):
        eps.handler("getOrdr")(lambda: None)

    @eps.handler("getOrder")
    def get_order(order_id: str) -> Order: ...

    with pytest.raises(EndpointError, match="already has a handler"):
        eps.handler("getOrder")(get_order)


def test_path_params_body_and_return_type_must_match():
    with pytest.raises(EndpointError, match="path param 'order_id'"):
        @EndpointHandlers().handler("getOrder")
        def no_id() -> Order: ...

    with pytest.raises(EndpointError, match="must return Order"):
        @EndpointHandlers().handler("getOrder")
        def wrong_return(order_id: str) -> ProductPage: ...

    with pytest.raises(EndpointError, match="no parameter typed OrderCreate"):
        @EndpointHandlers().handler("createOrder")
        def no_body() -> Order: ...

    @EndpointHandlers().handler("createOrder")
    def ok(body: OrderCreate) -> Order: ...


def test_query_params_get_their_limits_from_the_yaml():
    @EndpointHandlers().handler("listProducts")
    def search(q: str | None = None, tag: str | None = None, cursor: str | None = None,
               limit: int | None = None) -> ProductPage: ...

    params = inspect.signature(search).parameters
    spec = ENDPOINTS["listProducts"].query
    assert params["q"].annotation == str | None  # resolved, not a string
    assert any(getattr(m, "max_length", None) == spec["q"].max_length for m in params["q"].default.metadata)
    assert any(getattr(m, "ge", None) == spec["limit"].minimum for m in params["limit"].default.metadata)


def test_query_params_must_exist_and_be_optional_with_the_yaml_type():
    with pytest.raises(EndpointError, match=r"query param\(s\) \['cursor', 'limit', 'tag'\]"):
        @EndpointHandlers().handler("listProducts")
        def too_few(q: str | None = None) -> ProductPage: ...

    with pytest.raises(EndpointError, match="'limit' must be `int | None = None`"):
        @EndpointHandlers().handler("listProducts")
        def wrong_type(q: str | None = None, tag: str | None = None, cursor: str | None = None,
                       limit: str | None = None) -> ProductPage: ...


def test_mount_uses_the_yaml_and_needs_every_endpoint():
    eps = EndpointHandlers()

    @eps.handler("getOrder")
    def get_order(order_id: str) -> Order: ...

    with pytest.raises(EndpointError, match="no handler for"):
        mount(FastAPI(), [eps], "local")

    app = FastAPI()
    with pytest.raises(EndpointError, match="more than one router"):
        mount(app, [eps, eps], "local")


def test_mode_only_endpoints_are_skipped_in_other_modes():
    local = create_app(Settings(mode="local", _env_file=None), container=object())
    local_only = {n for n, e in ENDPOINTS.items() if e.mode == "local"}
    assert local_only and local_only <= {r.name for r in local.routes if isinstance(r, APIRoute)}
    hidden = {r.name for r in local.routes if isinstance(r, APIRoute) and not r.include_in_schema}
    assert hidden == {n for n, e in ENDPOINTS.items() if not e.public}
    gcp = create_app(Settings(mode="gcp", gcp_project="p", upload_bucket="u", media_bucket="m", internal_audience="a",
                              internal_invokers="i", transcode_topic="t", _env_file=None), container=object())
    assert not local_only & {r.name for r in gcp.routes if isinstance(r, APIRoute)}
