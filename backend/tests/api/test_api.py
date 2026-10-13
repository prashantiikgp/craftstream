"""End-to-end API tests in local mode, plus the contract check against models/endpoints.yml."""

from pathlib import Path

import yaml
from fastapi.testclient import TestClient

from app.main import API, app

client = TestClient(app)
SPEC = yaml.safe_load((Path(__file__).resolve().parents[3] / "models/endpoints.yml").read_text())


def test_routes_match_spec():
    served = {(m, r.path) for r in app.routes if getattr(r, "include_in_schema", False) for m in r.methods}
    expected = {(e["method"], SPEC["base_path"] + e["path"]) for e in SPEC["endpoints"]}
    assert expected <= served, f"missing routes: {expected - served}"


def test_full_buyer_flow():
    body = {"title": "Hand-thrown clay mug", "description": "Wheel-thrown and glazed by hand.",
            "price": 450, "tags": ["pottery", "kitchen"], "artisan_name": "Meera"}
    ticket = client.post(f"{API}/products", json=body).json()
    pid = ticket["product"]["id"]
    assert ticket["upload_method"] == "PUT"

    # Not searchable until its video is ready
    assert client.get(f"{API}/products", params={"q": "mug"}).json() == []

    client.post(f"{API}/products/{pid}/upload-complete")
    assert [p["id"] for p in client.get(f"{API}/products", params={"q": "clay"}).json()] == [pid]
    assert [p["id"] for p in client.get(f"{API}/products", params={"tag": "pottery"}).json()] == [pid]
    assert client.get(f"{API}/products", params={"tag": "jewelry"}).json() == []

    order = client.post(f"{API}/orders", json={"product_id": pid, "buyer_name": "Ravi", "quantity": 2}).json()
    assert order["status"] == "placed" and order["total"] == 900


def test_validation_comes_from_yaml():
    bad = {"title": "x", "description": "d", "price": 0, "artisan_name": "A"}
    assert client.post(f"{API}/products", json=bad).status_code == 422
