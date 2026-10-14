"""The video state machine: the YAML states match the wire model, and events move videos as configured."""

from pathlib import Path

import pytest
import yaml

from app.domain.media import video_lifecycle_engine as lc
from app.domain.media.video_lifecycle_loader import load_video_lifecycle_rules
from app.schemas.media.video_lifecycle_schema import VideoLifecycleRules

PRODUCT_YML = Path(__file__).resolve().parents[4] / "models" / "product.yml"


def test_states_are_the_video_status_enum_in_models():
    field = yaml.safe_load(PRODUCT_YML.read_text())["fields"]["video_status"]
    rules = load_video_lifecycle_rules()
    assert rules.states == field["values"]
    assert rules.initial == field["default"]


def test_happy_path():
    state = lc.initial_state()
    for event in ("transcode_started", "transcode_succeeded"):
        state = lc.next_state(state, event)
    assert state == lc.listable_state() and lc.is_orderable(state) and lc.is_playable(state)


def test_unreadable_upload_and_failed_job_end_in_a_state_buyers_never_see():
    for path in (["upload_unreadable"], ["transcode_started", "transcode_failed"]):
        state = lc.initial_state()
        for event in path:
            state = lc.next_state(state, event)
        assert state != lc.listable_state() and not lc.is_orderable(state) and not lc.is_playable(state)


def test_redelivered_events_are_ignored():
    rules = load_video_lifecycle_rules()
    processing = lc.next_state(rules.initial, "transcode_started")
    assert lc.next_state(processing, "transcode_started") is None
    ready = lc.next_state(processing, "transcode_succeeded")
    assert lc.next_state(ready, "transcode_succeeded") is None and lc.next_state(ready, "transcode_failed") is None


def test_only_final_transcoder_states_fire_events():
    assert lc.transcoder_event("SUCCEEDED") == "transcode_succeeded"
    assert lc.transcoder_event("FAILED") == "transcode_failed"
    assert lc.transcoder_event("RUNNING") is None and lc.transcoder_event("") is None


def _data() -> dict:
    return load_video_lifecycle_rules().model_dump(by_alias=True)


@pytest.mark.parametrize("change", [
    lambda d: d.update(listable="live"),                                  # unknown state
    lambda d: d["transitions"][0].update(to="gone"),                      # unknown target
    lambda d: d["transitions"][0].update(event="uploaded"),               # unknown event
    lambda d: d["transitions"].append(dict(d["transitions"][0])),         # same event twice from a state
    lambda d: d.update(states=[*d["states"], d["states"][0]]),            # repeated state
    lambda d: d.update(colour="red"),                                     # typo / unknown key
])
def test_bad_rules_are_rejected(change):
    data = _data()
    change(data)
    with pytest.raises(ValueError):
        VideoLifecycleRules.model_validate(data)


def test_rules_round_trip():
    assert VideoLifecycleRules.model_validate(_data()) == load_video_lifecycle_rules()
