import pytest
from pydantic import ValidationError

from app.core.settings import Settings


def test_local_is_the_default():
    assert Settings(_env_file=None).mode == "local"


def test_gcp_mode_requires_project_and_buckets():
    with pytest.raises(ValidationError, match="GCP_PROJECT"):
        Settings(mode="gcp", _env_file=None)
    s = Settings(mode="gcp", gcp_project="p", upload_bucket="u", media_bucket="m", internal_audience="https://api.test", internal_invokers="sa@p.iam.gserviceaccount.com", transcode_topic="t", _env_file=None)
    assert s.gcp_region == "asia-south1"
    assert s.internal_invoker_set == {"sa@p.iam.gserviceaccount.com"}


def test_reads_environment(monkeypatch):
    monkeypatch.setenv("CRAFTSTREAM_MODE", "gcp")
    monkeypatch.setenv("GCP_PROJECT", "craftstream-test")
    monkeypatch.setenv("UPLOAD_BUCKET", "up")
    monkeypatch.setenv("MEDIA_BUCKET", "media")
    monkeypatch.setenv("CORS_ORIGINS", "https://a.test, https://b.test")
    monkeypatch.setenv("INTERNAL_AUDIENCE", "https://api.test")
    monkeypatch.setenv("INTERNAL_INVOKERS", "a@x.test")
    monkeypatch.setenv("TRANSCODE_TOPIC", "transcode-done")
    s = Settings(_env_file=None)
    assert (s.mode, s.gcp_project) == ("gcp", "craftstream-test")
    assert s.cors_origin_list == ["https://a.test", "https://b.test"]
