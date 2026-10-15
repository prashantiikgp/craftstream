"""Liveness for Cloud Run. Route: models/endpoints.yml (internal, so not in /docs)."""

from __future__ import annotations

from app.api.deps import ContainerDep
from app.api.endpoints import EndpointHandlers

endpoints = EndpointHandlers()


@endpoints.handler("health")
def health(c: ContainerDep) -> dict:
    return {"ok": True, "mode": c.settings.mode}
