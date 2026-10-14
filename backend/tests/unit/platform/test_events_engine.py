"""GCP callback formats: routes match endpoints.yml, Eventarc types are filtered, Pub/Sub envelopes decode."""

import base64
import json
from pathlib import Path

import pytest
import yaml

from app.domain.platform import events_engine as ev
from app.domain.platform.events_loader import load_events_rules
from app.schemas.platform.events_schema import EventsRules

ENDPOINTS = Path(__file__).resolve().parents[4] / "models" / "endpoints.yml"


def _push(payload) -> dict:
    return {"message": {"data": base64.b64encode(json.dumps(payload).encode()).decode()}, "subscription": "s"}


def test_routes_are_the_internal_endpoints():
    internal = {e["path"] for e in yaml.safe_load(ENDPOINTS.read_text())["internal"]}
    assert ev.internal_prefix() + ev.upload_path() in internal
    assert ev.internal_prefix() + ev.transcode_path() in internal


def test_only_object_finalized_events_are_accepted():
    assert ev.accepts_event_type("google.cloud.storage.object.v1.finalized")
    assert ev.accepts_event_type(None)
    assert not ev.accepts_event_type("google.cloud.storage.object.v1.deleted")


def test_object_name():
    assert ev.object_name({"bucket": "b", "name": "raw/x/source"}) == "raw/x/source"
    assert ev.object_name({"bucket": "b"}) == ""


def test_transcoder_job_from_a_push_body():
    assert ev.transcoder_job(_push({"job": {"name": "jobs/1", "state": "SUCCEEDED"}})) == ("jobs/1", "SUCCEEDED")
    assert ev.transcoder_job(_push({"job": {"name": "jobs/1"}})) == ("jobs/1", "")


@pytest.mark.parametrize("body", [{}, {"message": {}}, {"message": {"data": "not-base64!"}}, {"message": "x"},
                                  _push({"nojob": 1}), _push({"job": {"state": "FAILED"}}), _push([1, 2])])
def test_other_bodies_are_not_job_results(body):
    with pytest.raises(ev.NotAJobResult):
        ev.transcoder_job(body)


@pytest.mark.parametrize("change", [
    lambda d: d.update(internal_prefix="internal/media"),          # not a path
    lambda d: d["transcode_result"].update(path="/transcoded/"),   # trailing slash
    lambda d: d["messages"].update(teapot="I'm a teapot"),         # unknown key
])
def test_bad_rules_are_rejected(change):
    data = load_events_rules().model_dump()
    change(data)
    with pytest.raises(ValueError):
        EventsRules.model_validate(data)
