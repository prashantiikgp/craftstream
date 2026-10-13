"""The GCP callbacks: Eventarc (upload finished) and Pub/Sub (transcode finished)."""

import base64
import json

from fastapi.testclient import TestClient

from app.infra.gcp import transcoder
from app.main import API, app

client = TestClient(app)


def _create() -> str:
    body = {"title": "Woven basket", "description": "Hand-woven cane.", "price": 900, "artisan_name": "Asha"}
    return client.post(f"{API}/products", json=body).json()["product"]["id"]


def test_upload_event_starts_transcoding():
    pid = _create()
    resp = client.post("/internal/media/uploaded", json={"bucket": "b", "name": f"raw/{pid}/source"})
    assert resp.status_code == 204
    assert client.get(f"{API}/products/{pid}").json()["video_status"] == "ready"  # local mode: instant


def test_upload_event_for_other_objects_is_ignored():
    resp = client.post("/internal/media/uploaded", json={"bucket": "b", "name": "something/else.mp4"})
    assert resp.status_code == 204


def test_transcode_notification_marks_ready_or_failed(monkeypatch):
    ok, bad = _create(), _create()
    jobs = {"jobs/ok": ok, "jobs/bad": bad}
    monkeypatch.setattr(transcoder, "product_id_for_job", jobs.get)

    for name, state in (("jobs/ok", "SUCCEEDED"), ("jobs/bad", "FAILED")):
        data = base64.b64encode(json.dumps({"job": {"name": name, "state": state}}).encode()).decode()
        resp = client.post("/internal/media/transcoded", json={"message": {"data": data}, "subscription": "s"})
        assert resp.status_code == 204

    ready = client.get(f"{API}/products/{ok}").json()
    assert ready["video_status"] == "ready" and ready["hls_url"].endswith(f"/hls/{ok}/manifest.m3u8")
    assert ready["thumbnail_url"]
    failed = client.get(f"{API}/products/{bad}").json()
    assert failed["video_status"] == "failed" and failed["hls_url"] is None
