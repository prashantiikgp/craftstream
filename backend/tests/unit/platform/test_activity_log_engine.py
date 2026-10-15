"""Activity log rules: the event catalogue and its templates, who may report what, limits, paging and expiry."""

from datetime import UTC, datetime, timedelta

import pytest
from pydantic import ValidationError

from app.domain.api.http_loader import load_http_rules
from app.domain.media.video_lifecycle_loader import load_video_lifecycle_rules
from app.domain.platform import activity_log_engine as al
from app.domain.platform.activity_log_loader import load_activity_log_rules
from app.generated.models import LogDetail, LogEntry, LogEntryCreate
from app.schemas.platform.activity_log_schema import ActivityLogRules

AT = datetime(2026, 10, 15, 9, 30, tzinfo=UTC)
RULES = load_activity_log_rules()

SERVER_EVENTS = {"listing_created", "upload_received", "upload_unreadable", "transcode_submitted",
                 "transcode_succeeded", "transcode_failed", "video_event_ignored", "order_placed", "order_rejected",
                 "internal_call_rejected", "unhandled_error"}
CLIENT_EVENTS = {"upload_started", "upload_interrupted", "upload_resumed", "upload_finished", "upload_failed",
                 "upload_too_long", "upload_cancelled"}


def _client(event: str, **details) -> LogEntryCreate:
    return LogEntryCreate(event=event, product_id="p1",
                          details=[LogDetail(key=k, value=str(v)) for k, v in details.items()])


def test_the_catalogue_has_every_server_and_client_event():
    by_source = {s: {n for n, e in al.events().items() if e.source == s} for s in ("api", "app")}
    assert by_source["api"] >= SERVER_EVENTS
    assert by_source["app"] >= CLIENT_EVENTS


def test_every_template_fills_from_its_details_alone():
    for name, rule in al.events().items():
        entry = al.build_entry(name, source=rule.source, entry_id="e", at=AT,
                               details=[(k, f"<{k}>") for k in rule.details])
        assert "{" not in entry.message and RULES.details.missing_value not in entry.message, name
        assert all(f"<{k}>" in entry.message for k in rule.details if f"{{{k}}}" in rule.message)


def test_server_entry_fills_level_group_message():
    e = al.server_entry("transcode_submitted", entry_id="e1", at=AT, product_id="p1",
                        details={"seconds": 12.3456, "cut_at_seconds": None, "job": "jobs/1"})
    assert (e.level, e.group, e.source) == ("info", "video", "api")
    assert e.message == "Making the streaming versions (144p and up)"
    assert [(d.key, d.value) for d in e.details] == [("seconds", "12.35"), ("job", "jobs/1")]  # None is left out
    assert e.product_id == "p1" and e.at == AT and e.id == "e1"


def test_a_missing_detail_shows_the_missing_value():
    e = al.server_entry("video_event_ignored", entry_id="e", at=AT, details={"event": "transcode_started"})
    assert e.message == f"Ignored transcode_started (the video was {RULES.details.missing_value})"


def test_whole_numbers_drop_their_decimals():
    e = al.server_entry("order_placed", entry_id="e", at=AT, details={"quantity": 2, "total": 900.0,
                                                                      "currency": "INR"})
    assert e.message == "Order placed for 2, total 900 INR"


def test_client_entry_for_a_client_event():
    e = al.client_entry(_client("upload_interrupted", sent="3 MB", size="40 MB", reason="network dropped"),
                        entry_id="e", at=AT)
    assert (e.level, e.group, e.source) == ("warning", "upload", "app")
    assert e.message == "Connection dropped during the upload; it will resume"
    assert [(d.key, d.value) for d in e.details] == [("sent", "3 MB"), ("size", "40 MB"), ("reason", "network dropped")]


def test_client_template_fills_from_the_details():
    e = al.client_entry(_client("upload_failed", reason="UploadRejected"), entry_id="e", at=AT)
    assert (e.level, e.message) == ("error", "Upload failed: UploadRejected")


def test_upload_too_long_needs_no_product():
    e = al.client_entry(LogEntryCreate(event="upload_too_long", details=[LogDetail(key="seconds", value="1085"),
                                                                         LogDetail(key="max", value="900")]),
                        entry_id="e", at=AT)
    assert e.product_id is None and e.level == "warning"
    assert [(d.key, d.value) for d in e.details] == [("seconds", "1085"), ("max", "900")]


def test_unknown_events_are_refused():
    with pytest.raises(al.UnknownEvent):
        al.client_entry(_client("upload_exploded"), entry_id="e", at=AT)
    with pytest.raises(al.UnknownEvent):
        al.server_entry("nope", entry_id="e", at=AT)


def test_the_app_may_not_report_api_events_and_the_api_not_app_events():
    with pytest.raises(al.NotReportable):
        al.client_entry(_client("order_placed"), entry_id="e", at=AT)
    with pytest.raises(al.NotReportable):
        al.server_entry("upload_started", entry_id="e", at=AT)


def test_server_details_are_cut_to_fit_never_rejected():
    d = RULES.details
    many = {f"k{i}": "x" * (d.max_value_length + 50) for i in range(d.max_per_entry + 5)}
    e = al.server_entry("upload_unreadable", entry_id="e", at=AT, details={"reason": "y" * 1000, **many})
    assert len(e.details) == d.max_per_entry
    assert all(len(x.value) <= d.max_value_length for x in e.details)
    LogEntry.model_validate(e.model_dump())  # still a valid LogEntry


def test_yaml_limits_fit_the_model():
    entry = LogEntry.model_fields
    assert RULES.details.max_per_entry <= next(m.max_length for m in entry["details"].metadata)
    key, value = LogDetail.model_fields["key"].metadata, LogDetail.model_fields["value"].metadata
    assert RULES.details.max_key_length <= next(m.max_length for m in key if hasattr(m, "max_length"))
    assert RULES.details.max_value_length <= next(m.max_length for m in value if hasattr(m, "max_length"))


def test_page_size_is_clamped():
    p = RULES.page_size
    assert al.page_size(None) == p.default
    assert al.page_size(p.max + 1000) == p.max
    assert al.page_size(3) == 3


def test_filters_must_be_model_values():
    al.check_filter("upload", "error")
    al.check_filter(None, None)
    for group, level in (("uploads", None), (None, "debug")):
        with pytest.raises(al.BadFilter):
            al.check_filter(group, level)


def test_entries_expire_after_keep_days():
    assert al.expire_at(AT) == AT + timedelta(days=RULES.keep_days)


def test_error_codes_are_api_error_codes():
    status = load_http_rules().errors.status
    for kind in ("unknown_event", "not_reportable", "bad_filter"):
        assert al.error(kind).code in status


def test_transcode_results_are_log_events():
    """media_service logs a finished transcode under its lifecycle event name."""
    for event in load_video_lifecycle_rules().transcoder_results.values():
        assert al.event_rule(event).source == RULES.sources.server


@pytest.mark.parametrize("change", [
    lambda d: d["events"]["order_placed"].update(message="Order for {buyer_name}"),     # not a declared detail
    lambda d: d["events"]["order_placed"].update(message="Order {total"),               # broken template
    lambda d: d["events"]["order_placed"].update(level="debug"),                        # not a model level
    lambda d: d["events"]["order_placed"].update(group="payments"),                     # not a model group
    lambda d: d["events"].update({"Bad-Name": d["events"]["order_placed"]}),            # not snake_case
    lambda d: d["events"].update({"x" * 41: d["events"]["order_placed"]}),              # longer than the model allows
    lambda d: d["page_size"].update(default=500),                                       # default over max
    lambda d: d["sources"].update(client="api"),                                        # same as server
    lambda d: d.update(colection="typo"),                                               # unknown key
])
def test_bad_rules_are_rejected(change):
    data = RULES.model_dump()
    change(data)
    with pytest.raises(ValidationError):
        ActivityLogRules.model_validate(data)
