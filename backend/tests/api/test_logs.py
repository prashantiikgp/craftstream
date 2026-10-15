"""GET /logs and POST /logs, and the entries the upload, video and order flows leave behind (local mode)."""

from __future__ import annotations

import json

from fastapi.testclient import TestClient

from app.api.deps import Container
from app.core.settings import Settings
from app.db.repositories.product_repo import InMemoryProductRepo
from app.domain.platform import activity_log_engine as al
from app.infra.gcp.auth import CallerRejected
from app.infra.local.local_auth import AllowAllCallers
from app.infra.local.local_storage import LocalStorage
from app.infra.local.local_transcoder import LocalTranscoder
from app.main import API, create_app


def _listing(client: TestClient, **overrides) -> dict:
    body = {"title": "Woven basket", "description": "Hand-woven cane.", "price": 450, "artisan_name": "Asha",
            **overrides}
    resp = client.post(f"{API}/products", json=body)
    assert resp.status_code == 201, resp.text
    return resp.json()


def _ready(client: TestClient) -> str:
    ticket = _listing(client)
    assert client.put(ticket["upload_url"], content=b"video").status_code == 200
    return ticket["product"]["id"]


def _logs(client: TestClient, **params) -> dict:
    resp = client.get(f"{API}/logs", params=params)
    assert resp.status_code == 200, resp.text
    return resp.json()


def _events(client: TestClient, **params) -> list[str]:
    return [e["event"] for e in _logs(client, **params)["items"]]


def test_the_upload_flow_leaves_its_steps(client):
    pid = _ready(client)
    assert set(_events(client, product_id=pid)) == {"listing_created", "upload_received", "transcode_submitted",
                                                    "transcode_succeeded"}
    items = _logs(client, product_id=pid)["items"]
    assert [e["at"] for e in items] == sorted((e["at"] for e in items), reverse=True)   # newest first
    assert all(e["source"] == "api" and e["message"] for e in items)
    assert all("upload" not in d["key"] or "url" not in d["key"] for e in items for d in e["details"])


def test_an_order_is_logged_without_the_buyer_name(client):
    pid = _ready(client)
    order = client.post(f"{API}/orders", json={"product_id": pid, "buyer_name": "Ravindra Secretname",
                                               "quantity": 2}).json()
    (entry,) = _logs(client, group="order")["items"]
    assert entry["event"] == "order_placed" and entry["order_id"] == order["id"] and entry["product_id"] == pid
    assert {d["key"]: d["value"] for d in entry["details"]} == {"quantity": "2", "total": "900", "currency": "INR"}
    assert "Secretname" not in json.dumps(_logs(client))


def test_a_refused_order_is_logged(client):
    pid = _listing(client)["product"]["id"]
    assert client.post(f"{API}/orders", json={"product_id": pid, "buyer_name": "Ravi"}).status_code == 409
    assert client.post(f"{API}/orders", json={"product_id": "nope", "buyer_name": "Ravi"}).status_code == 404
    reasons = [{d["key"]: d["value"] for d in e["details"]}["reason"] for e in _logs(client, group="order")["items"]]
    assert sorted(reasons) == ["not_found", "product_not_ready"]
    assert "Ravi" not in json.dumps(_logs(client))


def test_the_app_reports_a_client_event(client):
    pid = _listing(client)["product"]["id"]
    resp = client.post(f"{API}/logs", json={"event": "upload_interrupted", "product_id": pid, "details": [
        {"key": "sent", "value": "3 MB"}, {"key": "size", "value": "40 MB"}, {"key": "reason", "value": "offline"}]})
    assert resp.status_code == 201, resp.text
    entry = resp.json()
    assert (entry["level"], entry["group"], entry["source"]) == ("warning", "upload", "app")
    assert entry["message"] == "Connection dropped during the upload; it will resume"
    assert entry["id"] and entry["at"]
    assert _logs(client, product_id=pid, level="warning")["items"] == [entry]


def test_the_app_may_not_report_api_events_or_unknown_ones(client):
    resp = client.post(f"{API}/logs", json={"event": "order_placed"})
    assert resp.status_code == 403 and resp.json()["code"] == al.error("not_reportable").code
    resp = client.post(f"{API}/logs", json={"event": "upload_exploded"})
    assert resp.status_code == 422 and resp.json()["code"] == al.error("unknown_event").code
    assert _logs(client)["items"] == []


def test_client_posts_are_held_to_the_model_limits(client):
    too_many = [{"key": f"k{i}", "value": "v"} for i in range(11)]
    for body in ({"event": "upload_failed", "details": too_many},
                 {"event": "upload_failed", "details": [{"key": "reason", "value": "x" * 301}]}):
        resp = client.post(f"{API}/logs", json=body)
        assert resp.status_code == 422 and resp.json()["code"] == "validation_error"
    # The server decides level, group and source; whatever the app sends for them is ignored.
    entry = client.post(f"{API}/logs", json={"event": "upload_failed", "level": "info", "source": "api"}).json()
    assert (entry["level"], entry["source"]) == ("error", "app")


def test_paging_filters_and_bad_filters(client):
    for _ in range(3):
        _listing(client)
    client.post(f"{API}/logs", json={"event": "upload_failed", "details": [{"key": "reason", "value": "disk"}]})
    first = _logs(client, group="upload", limit=2)
    second = _logs(client, group="upload", limit=2, cursor=first["next_cursor"])
    assert len(first["items"]) == 2 and len(second["items"]) == 2 and second["next_cursor"] is None
    assert _events(client, level="error") == ["upload_failed"]
    resp = client.get(f"{API}/logs", params={"group": "everything"})
    assert resp.status_code == 422 and resp.json()["code"] == "validation_error"


def test_a_refused_internal_call_is_logged(settings: Settings, container: Container):
    class OnlyToken:
        def verify(self, authorization: str | None) -> str:
            raise CallerRejected("invalid token: expired")

    c = Container(settings=settings, products=container.products, orders=container.orders, storage=LocalStorage(),
                  transcoder=LocalTranscoder(), callers=OnlyToken())
    client = TestClient(create_app(settings, c))
    client.post("/internal/media/uploaded", json={"name": "raw/x/source"}, headers={"Authorization": "Bearer bad"})
    (entry,) = _logs(client, group="system")["items"]
    assert entry["event"] == "internal_call_rejected" and "Bearer" not in json.dumps(entry)


def test_an_unhandled_error_is_logged(settings: Settings):
    class Exploding(InMemoryProductRepo):
        def get(self, product_id):
            raise RuntimeError("secret detail")

    c = Container(settings=settings, products=Exploding(), orders=None, storage=LocalStorage(),
                  transcoder=LocalTranscoder(), callers=AllowAllCallers())
    client = TestClient(create_app(settings, c), raise_server_exceptions=False)
    assert client.get(f"{API}/products/p1").status_code == 500
    (entry,) = _logs(client, level="error")["items"]
    assert entry["event"] == "unhandled_error" and entry["message"] == f"Unexpected RuntimeError on {API}/products/p1"
    assert "secret" not in json.dumps(entry)
