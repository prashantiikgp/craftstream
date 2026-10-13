"""The lowest rung must fit the assignment's 50 kbps limit, and the GCP job must include every rung."""

from transcoder.gcp_job import build_job_config
from transcoder.ladder import load_ladder


def test_lowest_rung_fits_budget():
    spec, rungs = load_ladder()
    assert rungs[0].total_kbps <= spec["max_lowest_rung_total_kbps"]


def test_job_config_has_all_rungs():
    _, rungs = load_ladder()
    cfg = build_job_config("abc")
    assert len(cfg["elementaryStreams"]) == 2 * len(rungs)
    assert len(cfg["manifests"][0]["muxStreams"]) == 2 * len(rungs)
    assert all(m["container"] == "fmp4" for m in cfg["muxStreams"])
