"""Liveness for Cloud Run."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import ContainerDep

router = APIRouter(include_in_schema=False)


@router.get("/healthz", status_code=200)
def health(c: ContainerDep) -> dict:
    return {"ok": True, "mode": c.settings.mode}
