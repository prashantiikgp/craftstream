"""Walk the whole flow against a running API, local or deployed:

    health -> upload policy -> create listing -> resumable chunked upload -> wait until ready
    -> search (keyword + tag) -> product details -> place order

    backend/.venv/bin/python tools/smoke_test.py http://localhost:8000
    backend/.venv/bin/python tools/smoke_test.py https://craftstream-api-<n>.asia-south1.run.app --video my.mp4

Without --video it makes a 12 s test clip with FFmpeg. Exits non-zero on the first failure.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

import httpx


def ok(msg: str) -> None:
    print(f"  ok  {msg}")


def fail(msg: str) -> None:
    print(f"  FAIL {msg}")
    sys.exit(1)


def make_clip(path: Path) -> Path:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=24",
                    "-f", "lavfi", "-i", "sine=frequency=440", "-t", "12", "-c:v", "libx264", "-preset", "veryfast",
                    "-c:a", "aac", "-movflags", "+faststart", str(path)], check=True)
    return path


def upload(url: str, video: Path, chunk: int) -> None:
    """GCS resumable protocol: PUT chunks with Content-Range; 308 + Range means "send the next one"."""
    total = video.stat().st_size
    sent = 0
    with video.open("rb") as f, httpx.Client(timeout=120) as http:
        while sent < total:
            data = f.read(chunk)
            end = sent + len(data) - 1
            r = http.put(url, content=data, headers={"Content-Range": f"bytes {sent}-{end}/{total}"})
            if r.status_code == 308:
                sent = int(r.headers["Range"].split("-")[1]) + 1 if "Range" in r.headers else 0
                f.seek(sent)
            elif r.status_code in (200, 201):
                sent = total
            else:
                fail(f"upload chunk at {sent}: HTTP {r.status_code} {r.text[:200]}")
    ok(f"uploaded {total:,} bytes in {chunk:,}-byte chunks")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("base_url")
    ap.add_argument("--video", type=Path)
    ap.add_argument("--timeout", type=int, default=1800, help="seconds to wait for transcoding")
    a = ap.parse_args()
    base = a.base_url.rstrip("/")
    api = httpx.Client(base_url=f"{base}/api/v1", timeout=30)
    tag = f"smoke{uuid.uuid4().hex[:6]}"

    print(f"Smoke test against {base}")
    health = httpx.get(f"{base}/health", timeout=30).json()
    ok(f"health: mode={health['mode']}")

    policy = api.get("/upload-policy").json()
    ok(f"upload policy: max {policy['max_duration_seconds']} s, chunk {policy['chunk_size_bytes']:,} bytes")

    r = api.post("/products", json={"title": "Smoke test bowl", "description": "Turned on a lathe, oiled by hand.",
                                     "price": 499.5, "tags": [tag, "woodwork"], "artisan_name": "Smoke Bot"})
    if r.status_code != 201:
        fail(f"create product: {r.status_code} {r.text}")
    ticket = r.json()
    pid = ticket["product"]["id"]
    ok(f"listing {pid} created, status {ticket['product']['video_status']}")

    with tempfile.TemporaryDirectory() as tmp:
        video = a.video or make_clip(Path(tmp) / "clip.mp4")
        upload(ticket["upload_url"], video, ticket["chunk_size_bytes"])

    deadline = time.monotonic() + a.timeout
    while True:
        product = api.get(f"/products/{pid}").json()
        if product["video_status"] in ("ready", "failed"):
            break
        if time.monotonic() > deadline:
            fail(f"still {product['video_status']} after {a.timeout} s")
        time.sleep(10)
    if product["video_status"] != "ready":
        fail("transcoding failed")
    ok(f"video ready: {product['hls_url']}")

    manifest = httpx.get(product["hls_url"], timeout=30)
    if manifest.status_code != 200 or "#EXTM3U" not in manifest.text:
        fail(f"manifest not playable: HTTP {manifest.status_code}")
    ok(f"manifest served ({len(manifest.text.splitlines())} lines, cache: {manifest.headers.get('cache-control')})")

    page = api.get("/products", params={"q": "lathe bowl", "tag": tag}).json()
    if [p["id"] for p in page["items"]] != [pid]:
        fail(f"search did not find exactly the new product: {page}")
    ok("search by keyword + tag finds it")

    order = api.post("/orders", json={"product_id": pid, "buyer_name": "Smoke Buyer", "quantity": 2}).json()
    if order.get("status") != "placed" or order.get("total") != 999.0:
        fail(f"order: {order}")
    ok(f"order {order['id']} placed, total {order['currency']} {order['total']}")

    again = api.get(f"/orders/{order['id']}").json()
    if again != order:
        fail(f"order read back differs: {again}")
    ok("order reads back by id (Your orders after a restart)")
    print("PASS")


if __name__ == "__main__":
    main()
