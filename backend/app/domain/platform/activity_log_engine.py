"""The activity log: turn an event name and its facts into a LogEntry (level, group, message, expiry), decide
which events the app may report, and size the pages. Pure logic over ActivityLogRules; activity_log_service
stores the entries and wires the callers.

    server_entry("order_placed", entry_id=..., at=..., order_id=..., details={"quantity": 2, ...})
    client_entry(LogEntryCreate(event="upload_resumed", ...), entry_id=..., at=...)
"""

from __future__ import annotations

import typing
from collections.abc import Iterable, Mapping
from datetime import datetime, timedelta

from app.domain.platform.activity_log_loader import load_activity_log_rules
from app.generated.models import LogDetail, LogEntry, LogEntryCreate
from app.schemas.platform.activity_log_schema import (
    ENTRY_FIELDS,
    ActivityLogRules,
    ErrorRule,
    EventRule,
    Group,
    Level,
)


class UnknownEvent(ValueError):
    """The event is not in the catalogue."""


class NotReportable(ValueError):
    """The event exists, but not for this source (e.g. the app posting an API event)."""


class BadFilter(ValueError):
    """A group or level filter that LogEntry doesn't know."""


def _rules(rules: ActivityLogRules | None) -> ActivityLogRules:
    return rules or load_activity_log_rules()


def collection(rules: ActivityLogRules | None = None) -> str:
    return _rules(rules).collection


def expire_field(rules: ActivityLogRules | None = None) -> str:
    return _rules(rules).expire_field


def write_timeout_seconds(rules: ActivityLogRules | None = None) -> float:
    return _rules(rules).write_timeout_seconds


def mirror_to_stdout(rules: ActivityLogRules | None = None) -> bool:
    return _rules(rules).mirror_to_stdout


def error(kind: str, rules: ActivityLogRules | None = None) -> ErrorRule:
    """The code and message for unknown_event, not_reportable or bad_filter."""
    return getattr(_rules(rules).errors, kind)


def events(rules: ActivityLogRules | None = None) -> Mapping[str, EventRule]:
    return _rules(rules).events


def event_rule(event: str, rules: ActivityLogRules | None = None) -> EventRule:
    rule = _rules(rules).events.get(event)
    if rule is None:
        raise UnknownEvent(event)
    return rule


def page_size(requested: int | None, rules: ActivityLogRules | None = None) -> int:
    p = _rules(rules).page_size
    return max(1, min(requested or p.default, p.max))


def check_filter(group: str | None, level: str | None) -> None:
    """Raise BadFilter unless each given filter is one of LogEntry's groups / levels."""
    for value, allowed in ((group, typing.get_args(Group)), (level, typing.get_args(Level))):
        if value is not None and value not in allowed:
            raise BadFilter(f"{value!r} is not one of {', '.join(allowed)}")


def expire_at(at: datetime, rules: ActivityLogRules | None = None) -> datetime:
    """When the Firestore TTL policy may delete an entry written at `at`."""
    return at + timedelta(days=_rules(rules).keep_days)


def _text(value: object, rules: ActivityLogRules) -> str:
    d = rules.details
    if isinstance(value, float):
        value = f"{value:.{d.float_decimals}f}".rstrip("0").rstrip(".")
    return str(value)[:d.max_value_length]


def build_entry(event: str, *, source: str, entry_id: str, at: datetime, product_id: str | None = None,
                order_id: str | None = None, details: Iterable[tuple[str, object]] = (),
                rules: ActivityLogRules | None = None) -> LogEntry:
    """A complete entry for `event` written by `source`. Details with no value (None) are left out; the rest are
    cut to the limits in the rules, never rejected. Raises UnknownEvent or NotReportable."""
    r = _rules(rules)
    rule = event_rule(event, r)
    if rule.source != source:
        raise NotReportable(f"{event} is reported by {rule.source}, not {source}")
    limits = r.details
    kept = [LogDetail(key=str(k)[:limits.max_key_length], value=_text(v, r))
            for k, v in details if v is not None][:limits.max_per_entry]
    fields = dict.fromkeys((*rule.details, *ENTRY_FIELDS), limits.missing_value)
    fields |= {k: v for k, v in (("product_id", product_id), ("order_id", order_id)) if v}
    fields |= {d.key: d.value for d in kept}
    return LogEntry(id=entry_id, event=event, product_id=product_id, order_id=order_id, details=kept,
                    level=rule.level, group=rule.group, source=rule.source, message=rule.message.format_map(fields),
                    at=at)


def server_entry(event: str, *, entry_id: str, at: datetime, product_id: str | None = None,
                 order_id: str | None = None, details: Mapping[str, object] | None = None,
                 rules: ActivityLogRules | None = None) -> LogEntry:
    """An entry the API records about itself."""
    r = _rules(rules)
    return build_entry(event, source=r.sources.server, entry_id=entry_id, at=at, product_id=product_id,
                       order_id=order_id, details=(details or {}).items(), rules=r)


def client_entry(body: LogEntryCreate, *, entry_id: str, at: datetime,
                 rules: ActivityLogRules | None = None) -> LogEntry:
    """An entry the app reports. Only client events are accepted; the model already limits the details."""
    r = _rules(rules)
    return build_entry(body.event, source=r.sources.client, entry_id=entry_id, at=at, product_id=body.product_id,
                       order_id=body.order_id, details=[(d.key, d.value) for d in body.details], rules=r)
