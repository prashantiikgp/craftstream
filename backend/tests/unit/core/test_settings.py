import pytest
from pydantic import ValidationError

from app.core.settings import Settings


def test_local_is_the_default():
    assert Settings(_env_file=None).mode == "local"


def test_gcp_mode_requires_project_and_buckets():
    with pytest.raises(ValidationError, match="GCP_PROJECT"):
        Settings(mode="gcp", _env_file=None)
    s = Settings(mode="gcp", gcp_project="p", upload_bucket="u", media_bucket="m", _env_file=None)
    assert s.gcp_region == "asia-south1"


def test_reads_environment(monkeypatch):
    monkeypatch.setenv("CRAFTSTREAM_MODE", "gcp")
    monkeypatch.setenv("GCP_PROJECT", "craftstream-test")
    monkeypatch.setenv("UPLOAD_BUCKET", "up")
    monkeypatch.setenv("MEDIA_BUCKET", "media")
    monkeypatch.setenv("CORS_ORIGINS", "https://a.test, https://b.test")
    s = Settings(_env_file=None)
    assert (s.mode, s.gcp_project) == ("gcp", "craftstream-test")
    assert s.cors_origin_list == ["https://a.test", "https://b.test"]
