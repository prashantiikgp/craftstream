"""Activity log endpoints: page through the log, and let the app report the upload steps only it sees."""

from __future__ import annotations

from fastapi import APIRouter, Query

from app.api.deps import ActivityDep
from app.generated.models import LogEntry, LogEntryCreate, LogPage

router = APIRouter()


@router.get("/logs", response_model=LogPage, status_code=200)
def list_logs(
    activity: ActivityDep,
    group: str | None = Query(None, max_length=20),
    level: str | None = Query(None, max_length=20),
    product_id: str | None = Query(None, max_length=100),
    cursor: str | None = Query(None, max_length=100),
    limit: int | None = Query(None, ge=1),
) -> LogPage:
    return activity.page(group=group, level=level, product_id=product_id, cursor=cursor, limit=limit)


@router.post("/logs", response_model=LogEntry, status_code=201)
def create_log(body: LogEntryCreate, activity: ActivityDep) -> LogEntry:
    return activity.report(body)
