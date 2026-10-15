"""Routes come from models/endpoints.yml. A router module registers its typed handlers by endpoint name:

    endpoints = EndpointHandlers()

    @endpoints.handler("listProducts")
    def list_products(catalog: CatalogDep, q: str | None = None, limit: int | None = None) -> ProductPage: ...

and `mount` adds them to the app with what the YAML says (via app/generated/api.py): method, full path, success
status, query-param limits, the response model, the summary and operationId in /docs, whether /docs shows it at all
(internal endpoints are hidden) and the mode it is mounted in (`mode: local`). The handler keeps its typed
signature, so /docs still shows the generated request and response models and the path and query params.

Registration checks the handler against the YAML and fails at import: an unknown name, a name handled twice, a
query param the handler lacks or types differently, a path param it lacks, or a body or return type that is not the
model the YAML names. `mount` fails at start-up if any endpoint in the YAML has no handler.
"""

from __future__ import annotations

import inspect
import re
import typing
from collections.abc import Callable, Iterable, Sequence
from typing import Any, TypeVar

from fastapi import APIRouter, FastAPI, Query, params

from app.generated import models
from app.generated.api import ENDPOINTS, Endpoint, QueryParam

F = TypeVar("F", bound=Callable[..., Any])

_QUERY_TYPES = {"string": str, "integer": int}
_PATH_PARAM = re.compile(r"{(\w+)}")


class EndpointError(RuntimeError):
    """A handler does not match models/endpoints.yml (or an endpoint has no handler)."""


class EndpointHandlers:
    """The handlers one router module serves, by endpoint name, plus dependencies shared by all of them."""

    def __init__(self, dependencies: Sequence[params.Depends] = ()):
        self.dependencies = list(dependencies)
        self.handlers: dict[str, Callable[..., Any]] = {}

    def handler(self, name: str) -> Callable[[F], F]:
        def register(fn: F) -> F:
            where = f"{fn.__module__}.{fn.__qualname__}"
            if name not in ENDPOINTS:
                raise EndpointError(f"{where}: {name!r} is not an endpoint in models/endpoints.yml")
            if name in self.handlers:
                raise EndpointError(f"{where}: {name!r} already has a handler")
            fn.__signature__ = _signature(fn, ENDPOINTS[name], where)  # type: ignore[attr-defined]
            self.handlers[name] = fn
            return fn

        return register


def mount(app: FastAPI, groups: Iterable[EndpointHandlers], mode: str) -> None:
    """Add every group's handlers to `app`, skipping endpoints declared for another mode."""
    handled: set[str] = set()
    for group in groups:
        router = APIRouter(dependencies=group.dependencies)
        for name, fn in group.handlers.items():
            if name in handled:
                raise EndpointError(f"{name!r} has a handler in more than one router")
            handled.add(name)
            ep = ENDPOINTS[name]
            if ep.mode not in (None, mode):
                continue
            extra: dict[str, Any] = {"response_model": _model(ep.returns)} if ep.returns else {}
            router.add_api_route(ep.path, fn, methods=[ep.method], status_code=ep.status, name=name,
                                 operation_id=name, summary=ep.summary or None, include_in_schema=ep.public, **extra)
        app.include_router(router)
    missing = sorted(set(ENDPOINTS) - handled)
    if missing:
        raise EndpointError(f"no handler for {missing} (models/endpoints.yml)")


def _model(name: str) -> type:
    return getattr(models, name)


def _query(spec: QueryParam) -> Any:
    return Query(None, max_length=spec.max_length, ge=spec.minimum, le=spec.maximum)


def _signature(fn: Callable[..., Any], ep: Endpoint, where: str) -> inspect.Signature:
    """The handler's signature with resolved annotations and each query param's limits from the YAML."""
    hints = typing.get_type_hints(fn, include_extras=True)
    sig = inspect.signature(fn)
    names = set(sig.parameters)
    for p in _PATH_PARAM.findall(ep.path):
        if p not in names:
            raise EndpointError(f"{where}: no parameter for path param {p!r} of {ep.path}")
    if ep.body and _model(ep.body) not in [t for n, t in hints.items() if n != "return"]:
        raise EndpointError(f"{where}: no parameter typed {ep.body}, the body in models/endpoints.yml")
    if ep.returns and hints.get("return") is not _model(ep.returns):
        raise EndpointError(f"{where}: must return {ep.returns}, as models/endpoints.yml says")
    params_out = []
    for p in sig.parameters.values():
        p = p.replace(annotation=hints.get(p.name, p.annotation))
        if p.name in ep.query:
            spec = ep.query[p.name]
            if p.annotation != _QUERY_TYPES[spec.type] | None or p.default is not None:
                raise EndpointError(f"{where}: query param {p.name!r} must be "
                                    f"`{_QUERY_TYPES[spec.type].__name__} | None = None` (models/endpoints.yml)")
            p = p.replace(default=_query(spec))
        params_out.append(p)
    missing = sorted(set(ep.query) - names)
    if missing:
        raise EndpointError(f"{where}: no parameter for query param(s) {missing} (models/endpoints.yml)")
    return sig.replace(parameters=params_out, return_annotation=hints.get("return", sig.return_annotation))
