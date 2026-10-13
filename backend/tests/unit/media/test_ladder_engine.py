"""The lowest rung must fit the assignment's 50 kbps limit, and the GCP job must include every rung."""

import pytest

from app.domain.media.ladder_engine import build_job_config, lowest_rung_within_budget, sorted_rungs
from app.domain.media.ladder_loader import load_ladder_rules


def test_lowest_rung_fits_budget():
    assert lowest_rung_within_budget()


def test_rungs_sorted_low_to_high():
    kbps = [r.total_kbps for r in sorted_rungs()]
    assert kbps == sorted(kbps)


def test_job_config_has_all_rungs():
    rungs = load_ladder_rules().rungs
    cfg = build_job_config()
    assert len(cfg["elementaryStreams"]) == 2 * len(rungs)
    assert len(cfg["manifests"][0]["muxStreams"]) == 2 * len(rungs)
    assert all(m["container"] == "fmp4" for m in cfg["muxStreams"])


def test_budget_violation_is_detected():
    rules = load_ladder_rules()
    too_big = rules.model_copy(update={"max_lowest_rung_total_kbps": sorted_rungs(rules)[0].total_kbps - 1})
    assert not lowest_rung_within_budget(too_big)


def test_unknown_yaml_key_is_rejected():
    data = load_ladder_rules().model_dump()
    data["segment_secs"] = 4  # typo
    with pytest.raises(ValueError):
        type(load_ladder_rules()).model_validate(data)


def test_duration_cap_adds_edit_list():
    cfg = build_job_config(input_uri="gs://up/raw/abc/source", max_duration_seconds=900)
    assert cfg["inputs"] == [{"key": "input0", "uri": "gs://up/raw/abc/source"}]
    assert cfg["editList"][0]["endTimeOffset"] == "900s"
    assert "editList" not in build_job_config()


def test_duration_cap_needs_input_uri():
    with pytest.raises(ValueError):
        build_job_config(max_duration_seconds=900)
