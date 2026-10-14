"""The GCP callbacks: Eventarc (upload finished) and Pub/Sub (transcode finished)."""

from __future__ import annotations

import base64
import json

import pytest
from fastapi.testclient import TestClient

from app.api.deps import Container
from app.core.errors import UnreadableVideo
from app.core.settings import Settings
from app.infra.gcp.auth import CallerRejected
from app.infra.local.local_auth import AllowAllCallers
from app.infra.local.local_storage import LocalStorage
from app.main import API, create_app


class AsyncTranscoder:
    """Behaves like the real Transcoder: submit returns a job, completion arrives later via Pub/Sub."""

    completes_immediately = False

    def __init__(self) -> None:
        self.jobs: dict[str, str] = {}
        self.caps: dict[str, int | None] = {}

    def submit(self, product_id: str, max_duration_seconds: int | None) -> str:
        self.jobs[f"jobs/{product_id}"] = product_id
        self.caps[product_id] = max_duration_seconds
        return f"jobs/{product_id}"

    def product_id_for_job(self, job_name: str) -> str | None:
        return self.jobs.get(job_name)


class CdnStorage(LocalStorage):
    """Uploads measure `duration` seconds; `UnreadableVideo` instead makes them unreadable."""

    duration: float | type[UnreadableVideo] = 12.0

    def duration_seconds(self, product_id: str) -> float | None:
        if self.duration is UnreadableVideo:
            raise UnreadableVideo("not a video")
        return self.duration

    def hls_url(self, product_id: str) -> str:
        return f"https://cdn.test/hls/{product_id}/manifest.m3u8"

    def thumbnail_url(self, product_id: str) -> str | None:
        return f"https://cdn.test/hls/{product_id}/thumb.jpeg"


class OnlyToken:
    def verify(self, authorization: str | None) -> str:
        if authorization != "Bearer good":
            raise CallerRejected("nope")
        return "sa@test"


@pytest.fixture
def gcp_like(settings: Settings, container: Container) -> TestClient:
    c = Container(settings=settings, products=container.products, orders=container.orders,
                  storage=CdnStorage(), transcoder=AsyncTranscoder(), callers=AllowAllCallers())
    return TestClient(create_app(settings, c))


def test_internal_calls_need_a_valid_caller(settings: Settings, container: Container):
    c = Container(settings=settings, products=container.products, orders=container.orders,
                  storage=CdnStorage(), transcoder=AsyncTranscoder(), callers=OnlyToken())
    client = TestClient(create_app(settings, c))
    body = {"bucket": "b", "name": "raw/x/source"}
    for headers in ({}, {"Authorization": "Bearer bad"}):
        resp = client.post("/internal/media/uploaded", json=body, headers=headers)
        assert resp.status_code == 401 and resp.json()["code"] == "unauthorized"
    assert client.post("/internal/media/uploaded", json=body, headers={"Authorization": "Bearer good"}).status_code == 204
    assert client.get(f"{API}/tags").status_code == 200  # public routes need no token


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


@pytest.mark.parametrize(("duration", "cap"), [(12.0, None), (900.0, None), (1085.5, 900)])
def test_only_videos_over_the_limit_are_capped(settings: Settings, container: Container, duration, cap):
    storage, transcoder = CdnStorage(), AsyncTranscoder()
    storage.duration = duration
    client = TestClient(create_app(settings, Container(settings=settings, products=container.products,
                                                       orders=container.orders, storage=storage,
                                                       transcoder=transcoder, callers=AllowAllCallers())))
    pid = _create(client)
    client.post("/internal/media/uploaded", json={"bucket": "b", "name": f"raw/{pid}/source"})
    assert transcoder.caps[pid] == cap


def test_an_unreadable_upload_fails_without_a_job(settings: Settings, container: Container):
    storage, transcoder = CdnStorage(), AsyncTranscoder()
    storage.duration = UnreadableVideo
    client = TestClient(create_app(settings, Container(settings=settings, products=container.products,
                                                       orders=container.orders, storage=storage,
                                                       transcoder=transcoder, callers=AllowAllCallers())))
    pid = _create(client)
    assert client.post("/internal/media/uploaded", json={"bucket": "b", "name": f"raw/{pid}/source"}).status_code == 204
    assert _status(client, pid)["video_status"] == "failed" and not transcoder.jobs


def test_only_object_finalized_events_start_a_transcode(gcp_like):
    pid = _create(gcp_like)
    body = {"bucket": "b", "name": f"raw/{pid}/source"}
    deleted = {"ce-type": "google.cloud.storage.object.v1.deleted"}
    assert gcp_like.post("/internal/media/uploaded", json=body, headers=deleted).status_code == 204
    assert _status(gcp_like, pid)["video_status"] == "awaiting_upload"
    finalized = {"ce-type": "google.cloud.storage.object.v1.finalized"}
    assert gcp_like.post("/internal/media/uploaded", json=body, headers=finalized).status_code == 204
    assert _status(gcp_like, pid)["video_status"] == "processing"


def test_a_redelivered_result_after_ready_changes_nothing(gcp_like):
    pid = _create(gcp_like)
    gcp_like.post("/internal/media/uploaded", json={"bucket": "b", "name": f"raw/{pid}/source"})
    _notify(gcp_like, f"jobs/{pid}", "SUCCEEDED")
    assert _notify(gcp_like, f"jobs/{pid}", "FAILED").status_code == 204
    assert _status(gcp_like, pid)["video_status"] == "ready"
