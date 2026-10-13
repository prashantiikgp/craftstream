"""The GCP callbacks: Eventarc (upload finished) and Pub/Sub (transcode finished)."""

from __future__ import annotations

import base64
import json

import pytest
from fastapi.testclient import TestClient

from app.api.deps import Container
from app.core.settings import Settings
from app.infra.local.local_storage import LocalStorage
from app.main import API, create_app


class AsyncTranscoder:
    """Behaves like the real Transcoder: submit returns a job, completion arrives later via Pub/Sub."""

    completes_immediately = False

    def __init__(self) -> None:
        self.jobs: dict[str, str] = {}

    def submit(self, product_id: str, max_duration_seconds: int) -> str:
        self.jobs[f"jobs/{product_id}"] = product_id
        return f"jobs/{product_id}"

    def product_id_for_job(self, job_name: str) -> str | None:
        return self.jobs.get(job_name)


class CdnStorage(LocalStorage):
    def hls_url(self, product_id: str) -> str:
        return f"https://cdn.test/hls/{product_id}/manifest.m3u8"

    def thumbnail_url(self, product_id: str) -> str | None:
        return f"https://cdn.test/hls/{product_id}/thumb.jpeg"


@pytest.fixture
def gcp_like(settings: Settings, container: Container) -> TestClient:
    c = Container(settings=settings, products=container.products, orders=container.orders,
                  storage=CdnStorage(), transcoder=AsyncTranscoder())
    return TestClient(create_app(settings, c))


def _create(client: TestClient) -> str:
    body = {"title": "Woven basket", "description": "Hand-woven cane.", "price": 900, "artisan_name": "Asha"}
    return client.post(f"{API}/products", json=body).json()["product"]["id"]


def _notify(client: TestClient, name: str, state: str):
    data = base64.b64encode(json.dumps({"job": {"name": name, "state": state}}).encode()).decode()
    return client.post("/internal/media/transcoded", json={"message": {"data": data}, "subscription": "s"})


def _status(client: TestClient, pid: str) -> dict:
    return client.get(f"{API}/products/{pid}").json()


def test_upload_event_then_transcode_success(gcp_like):
    pid = _create(gcp_like)
    assert gcp_like.post("/internal/media/uploaded", json={"bucket": "b", "name": f"raw/{pid}/source"}).status_code == 204
    assert _status(gcp_like, pid)["video_status"] == "processing"

    assert _notify(gcp_like, f"jobs/{pid}", "RUNNING").status_code == 204  # not final: ignored
    assert _status(gcp_like, pid)["video_status"] == "processing"

    assert _notify(gcp_like, f"jobs/{pid}", "SUCCEEDED").status_code == 204
    p = _status(gcp_like, pid)
    assert p["video_status"] == "ready"
    assert p["hls_url"] == f"https://cdn.test/hls/{pid}/manifest.m3u8" and p["thumbnail_url"]


def test_transcode_failure_marks_failed(gcp_like):
    pid = _create(gcp_like)
    gcp_like.post("/internal/media/uploaded", json={"bucket": "b", "name": f"raw/{pid}/source"})
    _notify(gcp_like, f"jobs/{pid}", "FAILED")
    p = _status(gcp_like, pid)
    assert p["video_status"] == "failed" and p["hls_url"] is None


def test_duplicate_upload_event_is_harmless(gcp_like):
    pid = _create(gcp_like)
    for _ in range(2):
        gcp_like.post("/internal/media/uploaded", json={"bucket": "b", "name": f"raw/{pid}/source"})
    assert _status(gcp_like, pid)["video_status"] == "processing"


def test_events_for_unknown_objects_and_jobs_are_ignored(gcp_like):
    assert gcp_like.post("/internal/media/uploaded", json={"name": "something/else.mp4"}).status_code == 204
    assert gcp_like.post("/internal/media/uploaded", json={"name": "raw/nope/source"}).status_code == 204
    assert _notify(gcp_like, "jobs/unknown", "SUCCEEDED").status_code == 204


def test_malformed_notification_is_rejected(gcp_like):
    resp = gcp_like.post("/internal/media/transcoded", json={"message": {"data": "not-base64!"}})
    assert resp.status_code == 400 and resp.json()["code"] == "bad_request"


def test_local_mode_finishes_instantly(client):
    pid = _create(client)
    client.post("/internal/media/uploaded", json={"bucket": "b", "name": f"raw/{pid}/source"})
    assert _status(client, pid)["video_status"] == "ready"
