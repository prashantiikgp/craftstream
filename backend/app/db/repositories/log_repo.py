"""Where activity log entries are stored. `InMemoryLogRepo` locally and in tests; `FirestoreLogRepo` on GCP.

Pages are newest first (`at` descending, then id), optionally narrowed by group, level and product. A page
starts after the entry whose id is the cursor (the last id of the previous page). Each stored entry also
carries an expiry timestamp that a Firestore TTL policy uses to delete it (platform/activity_log.yml).
"""

from __future__ import annotations

from datetime import datetime
from typing import Protocol

from app.generated.models import LogEntry

# The fields a page can be narrowed by (equality), and the newest-first order. infra/gcp/resources.yml has one
# composite index (field, ORDER_BY desc) per filter field; test_infra_resources.py checks it.
FILTERS = ("group", "level", "product_id")
ORDER_BY = "at"


class LogRepo(Protocol):
    def add(self, entry: LogEntry, expire_at: datetime) -> None: ...
    def page(self, *, group: str | None, level: str | None, product_id: str | None, cursor: str | None,
             limit: int) -> list[LogEntry]: ...  # up to `limit` entries after the cursor, newest first


def _newest_first(entry: LogEntry) -> tuple[datetime, str]:
    return getattr(entry, ORDER_BY), entry.id


class InMemoryLogRepo:
    def __init__(self) -> None:
        self._entries: dict[str, LogEntry] = {}
        self.expiry: dict[str, datetime] = {}

    def add(self, entry: LogEntry, expire_at: datetime) -> None:
        self._entries[entry.id] = entry.model_copy(deep=True)
        self.expiry[entry.id] = expire_at

    def page(self, *, group: str | None, level: str | None, product_id: str | None, cursor: str | None,
             limit: int) -> list[LogEntry]:
        wanted = dict(zip(FILTERS, (group, level, product_id), strict=True))
        found = sorted((e for e in self._entries.values()
                        if all(v is None or getattr(e, k) == v for k, v in wanted.items())),
                       key=_newest_first, reverse=True)
        if cursor is not None:
            ids = [e.id for e in found]
            found = found[ids.index(cursor) + 1:] if cursor in ids else []
        return [e.model_copy(deep=True) for e in found[:limit]]


class FirestoreLogRepo:
    """One document per entry (id = entry id): the LogEntry plus the expiry field. Collection, expiry field and
    write timeout come from platform/activity_log.yml (passed in by api/deps.py).

    Queries filter by equality on group / level / product_id and order by `at` desc (then document id desc).
    Firestore merges the composite indexes (group, at desc), (level, at desc) and (product_id, at desc) for any
    mix of filters (infra/gcp/resources.yml).
    """

    def __init__(self, project: str, collection: str, expire_field: str, timeout_seconds: float) -> None:
        from google.cloud import firestore  # imported lazily so local mode needs no GCP libs

        self._col = firestore.Client(project=project).collection(collection)
        self._expire_field, self._timeout = expire_field, timeout_seconds

    def add(self, entry: LogEntry, expire_at: datetime) -> None:
        self._col.document(entry.id).set({**entry.model_dump(), self._expire_field: expire_at},
                                         timeout=self._timeout)

    def page(self, *, group: str | None, level: str | None, product_id: str | None, cursor: str | None,
             limit: int) -> list[LogEntry]:
        from google.cloud import firestore
        from google.cloud.firestore_v1.base_query import FieldFilter

        query = self._col
        for field, value in zip(FILTERS, (group, level, product_id), strict=True):
            if value is not None:
                query = query.where(filter=FieldFilter(field, "==", value))
        query = (query.order_by(ORDER_BY, direction=firestore.Query.DESCENDING)
                 .order_by(firestore.FieldPath.document_id(), direction=firestore.Query.DESCENDING))
        if cursor is not None:
            last = self._col.document(cursor).get()
            if not last.exists:
                return []
            query = query.start_after(last)
        return [_to_entry(d.to_dict()) for d in query.limit(limit).stream()]


def _to_entry(data: dict) -> LogEntry:
    return LogEntry(**{k: v for k, v in data.items() if k in LogEntry.model_fields})
