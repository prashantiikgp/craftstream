"""Activity log endpoints: page through the log, and let the app report the upload steps only it sees.
Routes and query limits: models/endpoints.yml."""

from __future__ import annotations

from app.api.deps import ActivityDep
from app.api.endpoints import EndpointHandlers
from app.generated.models import LogEntry, LogEntryCreate, LogPage

endpoints = EndpointHandlers()


@endpoints.handler("listLogs")
def list_logs(
    activity: ActivityDep,
    group: str | None = None,
    level: str | None = None,
    product_id: str | None = None,
    cursor: str | None = None,
    limit: int | None = None,
) -> LogPage:
    return activity.page(group=group, level=level, product_id=product_id, cursor=cursor, limit=limit)


@endpoints.handler("createLog")
def create_log(body: LogEntryCreate, activity: ActivityDep) -> LogEntry:
    return activity.report(body)
