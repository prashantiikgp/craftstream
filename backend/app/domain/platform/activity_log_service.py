"""The activity log: the API records its own steps, the app reports the upload steps only it sees, and anyone can
page through them. Events, levels, groups, messages and limits come from platform/activity_log.yml
(activity_log_engine); entries are stored through a LogRepo.

    activity.record("transcode_submitted", product_id=pid, seconds=12.4, job=name)   # never raises

Only ids, sizes, durations, states and reasons go into details: never a buyer's name, an upload URL, a token
or a request body.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime

from app.core.errors import DomainError
from app.core.ids import new_id, now
from app.db.repositories.log_repo import LogRepo
from app.domain.platform import activity_log_engine as engine
from app.generated.models import LogEntry, LogEntryCreate, LogPage

log = logging.getLogger(__name__)


def _refused(kind: str, e: Exception) -> DomainError:
    err = engine.error(kind)
    return DomainError(err.message, code=err.code, details=[str(e)])


class ActivityLogService:
    def __init__(self, repo: LogRepo, clock: Callable[[], datetime] = now, ids: Callable[[], str] = new_id) -> None:
        self._repo, self._clock, self._ids = repo, clock, ids

    def record(self, event: str, /, *, product_id: str | None = None, order_id: str | None = None,
               **details: object) -> None:
        """Store one of the API's own events. A log that can't be written must never fail the caller's request:
        any error is written to stdout and swallowed."""
        try:
            entry = engine.server_entry(event, entry_id=self._ids(), at=self._clock(), product_id=product_id,
                                        order_id=order_id, details=details)
            self._store(entry)
        except Exception:
            log.exception("activity log entry not written", extra={"event": event, "product_id": product_id,
                                                                    "order_id": order_id})

    def report(self, body: LogEntryCreate) -> LogEntry:
        """Store an upload step the app reports. Only client events from the catalogue are accepted."""
        try:
            entry = engine.client_entry(body, entry_id=self._ids(), at=self._clock())
        except engine.UnknownEvent as e:
            raise _refused("unknown_event", e) from e
        except engine.NotReportable as e:
            raise _refused("not_reportable", e) from e
        self._store(entry)
        return entry

    def page(self, group: str | None, level: str | None, product_id: str | None, cursor: str | None,
             limit: int | None) -> LogPage:
        try:
            engine.check_filter(group, level)
        except engine.BadFilter as e:
            raise _refused("bad_filter", e) from e
        size = engine.page_size(limit)
        found = self._repo.page(group=group, level=level, product_id=product_id, cursor=cursor, limit=size + 1)
        items = found[:size]
        return LogPage(items=items, next_cursor=items[-1].id if len(found) > size else None)

    def _store(self, entry: LogEntry) -> None:
        if engine.mirror_to_stdout():
            log.log(logging.getLevelNamesMapping()[entry.level.upper()], entry.message,
                    extra={"event": entry.event, "source": entry.source, "product_id": entry.product_id,
                           "order_id": entry.order_id, "details": {d.key: d.value for d in entry.details}})
        self._repo.add(entry, engine.expire_at(entry.at))
