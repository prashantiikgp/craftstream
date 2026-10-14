"""ffprobe limits come from ingest.yml."""

import pytest

from app.domain.media import ingest_engine
from app.domain.media.ingest_loader import load_ingest_rules
from app.schemas.media.ingest_schema import IngestRules


def test_timeout_comes_from_the_rules():
    assert ingest_engine.probe_timeout_seconds() == load_ingest_rules().probe_timeout_seconds > 0


def test_error_text_keeps_the_end():
    rules = IngestRules(probe_timeout_seconds=1, error_text_max_chars=5)
    assert ingest_engine.error_text("  first line\nmoov atom not found \n", "x", rules) == "found"
    assert ingest_engine.error_text("  \n", "ffprobe failed", rules) == "ffprobe failed"


@pytest.mark.parametrize("data", [
    {"probe_timeout_seconds": 0, "error_text_max_chars": 200},
    {"probe_timeout_seconds": 60, "error_text_max_chars": 200, "retries": 2},
])
def test_bad_rules_are_rejected(data):
    with pytest.raises(ValueError):
        IngestRules.model_validate(data)
