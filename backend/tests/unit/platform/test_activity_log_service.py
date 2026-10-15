"""The activity log service over the in-memory repo: newest-first paging, filters, expiry, and that recording
never fails the caller."""

import itertools
import logging
from datetime import UTC, datetime, timedelta

import pytest

from app.core.errors import DomainError
from app.db.repositories.log_repo import InMemoryLogRepo
from app.domain.platform import activity_log_engine as al
from app.domain.platform.activity_log_service import ActivityLogService
from app.generated.models import LogEntryCreate

START = datetime(2026, 10, 15, 9, 0, tzinfo=UTC)


@pytest.fixture
def records():
    """Records from the service's logger (app logs may not propagate to the root, so caplog can't see them)."""
    got: list[logging.LogRecord] = []
    handler = logging.Handler()
    handler.emit = got.append
    logger = logging.getLogger("app.domain.platform.activity_log_service")
    old = logger.level
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    yield got
    logger.removeHandler(handler)
    logger.setLevel(old)


def _service(repo=None) -> tuple[ActivityLogService, InMemoryLogRepo]:
    repo = repo or InMemoryLogRepo()
    ticks = itertools.count()
    ids = (f"id{i:03d}" for i in itertools.count())
    return ActivityLogService(repo, clock=lambda: START + timedelta(seconds=next(ticks)),
                              ids=lambda: next(ids)), repo


def test_pages_are_newest_first_and_follow_the_cursor():
    svc, _ = _service()
    for _ in range(5):
        svc.record("listing_created", product_id="p1")
    first = svc.page(None, None, None, None, 2)
    second = svc.page(None, None, None, first.next_cursor, 2)
    third = svc.page(None, None, None, second.next_cursor, 2)
    ats = [e.at for e in first.items + second.items + third.items]
    assert ats == sorted(ats, reverse=True) and len(ats) == 5
    assert third.next_cursor is None
    assert svc.page(None, None, None, "no-such-id", 2).items == []


def test_ties_on_time_are_ordered_by_id():
    repo = InMemoryLogRepo()
    svc = ActivityLogService(repo, clock=lambda: START, ids=iter(["a", "c", "b"]).__next__)
    for _ in range(3):
        svc.record("listing_created")
    assert [e.id for e in svc.page(None, None, None, None, None).items] == ["c", "b", "a"]


def test_filters_by_group_level_and_product():
    svc, _ = _service()
    svc.record("listing_created", product_id="p1")
    svc.record("upload_unreadable", product_id="p1", reason="not a video")
    svc.record("listing_created", product_id="p2")
    assert {e.event for e in svc.page("video", None, None, None, None).items} == {"upload_unreadable"}
    assert {e.event for e in svc.page(None, "error", None, None, None).items} == {"upload_unreadable"}
    assert len(svc.page("upload", None, "p1", None, None).items) == 1
    assert len(svc.page(None, None, "p2", None, None).items) == 1


def test_bad_filters_are_validation_errors():
    svc, _ = _service()
    with pytest.raises(DomainError) as e:
        svc.page("uploads", None, None, None, None)
    assert e.value.code == al.error("bad_filter").code


def test_entries_carry_their_expiry():
    svc, repo = _service()
    svc.record("listing_created", product_id="p1")
    (entry,) = svc.page(None, None, None, None, None).items
    assert repo.expiry[entry.id] == al.expire_at(entry.at)


def test_record_never_raises(records):
    class Broken(InMemoryLogRepo):
        def add(self, entry, expire_at):
            raise RuntimeError("firestore down")

    svc, _ = _service(Broken())
    svc.record("listing_created", product_id="p1")       # storage fails
    svc.record("no_such_event", product_id="p1")         # a bug in the caller
    svc.record("upload_started", product_id="p1")        # a client event from the server
    assert sum("not written" in r.getMessage() for r in records) == 3


def test_report_refuses_unknown_and_api_events():
    svc, _ = _service()
    for event, kind in (("nope", "unknown_event"), ("order_placed", "not_reportable")):
        with pytest.raises(DomainError) as e:
            svc.report(LogEntryCreate(event=event))
        assert e.value.code == al.error(kind).code


def test_entries_are_mirrored_to_stdout(records):
    svc, _ = _service()
    svc.record("upload_unreadable", product_id="p1", reason="not a video")
    (rec,) = [r for r in records if getattr(r, "event", None) == "upload_unreadable"]
    assert rec.levelno == logging.ERROR and rec.product_id == "p1" and rec.details == {"reason": "not a video"}
