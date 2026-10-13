"""End-to-end API tests in local mode, plus the contract check against models/endpoints.yml."""

import uuid
from pathlib import Path

import yaml
from fastapi.routing import APIRoute
from fastapi.testclient import TestClient

from app.core.settings import settings
from app.main import API, app

client = TestClient(app)
SPEC = yaml.safe_load((Path(__file__).resolve().parents[3] / "models/endpoints.yml").read_text())
MiB = 1024 * 1024


def _new_product(tag: str, **overrides) -> dict:
    body = {"title": "Hand-thrown clay mug", "description": "Wheel-thrown and glazed by hand.",
            "price": 450, "tags": ["pottery", tag], "artisan_name": "Meera", **overrides}
    resp = client.post(f"{API}/products", json=body)
    assert resp.status_code == 201, resp.text
    return resp.json()


def _upload(ticket: dict, size: int = 3 * MiB) -> None:
    """Upload like the app does: chunk by chunk with Content-Range, expecting 308 until the last chunk."""
    url, chunk = ticket["upload_url"], ticket["chunk_size_bytes"]
    sent = 0
    while sent < size:
        end = min(sent + chunk, size) - 1
        resp = client.put(url, content=b"\0" * (end - sent + 1),
                          headers={"Content-Range": f"bytes {sent}-{end}/{size}"})
        if end + 1 < size:
            assert resp.status_code == 308 and resp.headers["Range"] == f"bytes=0-{end}"
        else:
            assert resp.status_code == 200
        sent = end + 1


def _unique_tag() -> str:
    return f"t{uuid.uuid4().hex[:8]}"


def test_routes_match_spec_exactly():
    served = {(m, r.path, r.status_code or 200) for r in app.routes if isinstance(r, APIRoute) for m in r.methods}
    expected = {(e["method"], SPEC["base_path"] + e["path"], e["status"]) for e in SPEC["endpoints"]}
    expected |= {(e["method"], e["path"], e["status"]) for e in SPEC["internal"]
                 if e.get("mode") in (None, settings.mode)}
    assert served == expected, f"missing: {expected - served}; not in models/endpoints.yml: {served - expected}"


def test_full_artisan_to_buyer_flow():
    tag = _unique_tag()
    ticket = _new_product(tag)
    pid = ticket["product"]["id"]
    assert ticket["upload_method"] == "PUT"
    assert ticket["product"]["video_status"] == "awaiting_upload"

    # Not searchable until its video is ready
    assert client.get(f"{API}/products", params={"tag": tag}).json()["items"] == []

    _upload(ticket, size=3 * ticket["chunk_size_bytes"] - 5)
    assert client.get(f"{API}/products/{pid}").json()["video_status"] == "ready"

    page = client.get(f"{API}/products", params={"q": "clay", "tag": tag}).json()
    assert [p["id"] for p in page["items"]] == [pid]
    assert "description" not in page["items"][0]  # summaries stay small for slow links
    assert client.get(f"{API}/products", params={"q": "clay", "tag": "jewelry"}).json()["items"] == []
    assert tag in client.get(f"{API}/tags").json()["tags"]

    order = client.post(f"{API}/orders", json={"product_id": pid, "buyer_name": "Ravi", "quantity": 2}).json()
    assert order["status"] == "placed" and order["total"] == 900 and order["currency"] == "INR"


def test_single_put_upload_without_content_range():
    ticket = _new_product(_unique_tag())
    assert client.put(ticket["upload_url"], content=b"video").status_code == 200
    assert client.get(f"{API}/products/{ticket['product']['id']}").json()["video_status"] == "ready"


def test_upload_status_query_reports_progress():
    ticket = _new_product(_unique_tag())
    size = 2 * ticket["chunk_size_bytes"]
    first = ticket["chunk_size_bytes"]
    client.put(ticket["upload_url"], content=b"\0" * first, headers={"Content-Range": f"bytes 0-{first - 1}/{size}"})
    # After a network drop the app asks how much arrived, then resumes from there
    resp = client.put(ticket["upload_url"], headers={"Content-Range": f"bytes */{size}"})
    assert resp.status_code == 308 and resp.headers["Range"] == f"bytes=0-{first - 1}"


def test_pagination_with_cursor():
    tag = _unique_tag()
    ids = []
    for _ in range(3):
        ticket = _new_product(tag)
        _upload(ticket, size=10)
        ids.append(ticket["product"]["id"])
    first = client.get(f"{API}/products", params={"tag": tag, "limit": 2}).json()
    assert len(first["items"]) == 2 and first["next_cursor"]
    second = client.get(f"{API}/products", params={"tag": tag, "limit": 2, "cursor": first["next_cursor"]}).json()
    assert len(second["items"]) == 1 and second["next_cursor"] is None
    assert {p["id"] for p in first["items"] + second["items"]} == set(ids)


def test_upload_policy_comes_from_yaml():
    policy = client.get(f"{API}/upload-policy").json()
    assert policy["max_duration_seconds"] == 900
    assert "video/mp4" in policy["allowed_mime_types"]
    assert policy["chunk_size_bytes"] % (256 * 1024) == 0


def test_errors_use_one_shape():
    bad = client.post(f"{API}/products", json={"title": "x", "description": "d", "price": 0, "artisan_name": "A"})
    assert bad.status_code == 422
    body = bad.json()
    assert body["code"] == "validation_error" and any("price" in d for d in body["details"])

    missing = client.get(f"{API}/products/does-not-exist")
    assert missing.status_code == 404 and missing.json()["code"] == "not_found"


def test_cannot_order_before_video_is_ready():
    ticket = _new_product(_unique_tag())
    resp = client.post(f"{API}/orders", json={"product_id": ticket["product"]["id"], "buyer_name": "Ravi"})
    assert resp.status_code == 400 and resp.json()["code"] == "bad_request"
