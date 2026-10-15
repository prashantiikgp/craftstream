"""Walk the whole flow against a running API, local or deployed:

    health -> upload policy -> create listing -> resumable chunked upload -> wait until ready
    -> search (keyword + tag) -> product details -> place order -> activity log has the server steps

    backend/.venv/bin/python tools/smoke_test.py http://localhost:8000
    backend/.venv/bin/python tools/smoke_test.py https://craftstream-api-<n>.asia-south1.run.app --video my.mp4

Without --video it makes a short test clip with FFmpeg. Exits non-zero on the first failure.
Routes (base path, paths by endpoint name) come from models/endpoints.yml; timeouts, the polling interval, the
listing and order it creates and the clip settings from tools/tools.yml.
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
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

from tools_loader import load_tools_config

CFG = load_tools_config().smoke_test
API_SPEC = yaml.safe_load((Path(__file__).resolve().parents[1] / "models" / "endpoints.yml").read_text())


def path(name: str, **params: str) -> str:
    """An endpoint's path from models/endpoints.yml (public ones relative to the base path)."""
    (ep,) = [e for e in API_SPEC["endpoints"] + API_SPEC["internal"] if e["name"] == name]
    return ep["path"].format(**params)


def ok(msg: str) -> None:
    print(f"  ok  {msg}")


def fail(msg: str) -> None:
    print(f"  FAIL {msg}")
    sys.exit(1)


def make_clip(dst: Path) -> Path:
    c = CFG.clip
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", f"testsrc2=size={c.size}:rate={c.fps}",
                    "-f", "lavfi", "-i", f"sine=frequency={c.tone_hz}", "-t", str(c.seconds), "-c:v", "libx264",
                    "-preset", c.preset, "-c:a", "aac", "-movflags", "+faststart", str(dst)], check=True)
    return dst


def upload(url: str, video: Path, chunk: int) -> None:
    """GCS resumable protocol: PUT chunks with Content-Range; 308 + Range means "send the next one"."""
    total = video.stat().st_size
    sent = 0
    with video.open("rb") as f, httpx.Client(timeout=CFG.upload_timeout_s) as http:
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
                fail(f"upload chunk at {sent}: HTTP {r.status_code} {r.text[:CFG.error_text_chars]}")
    ok(f"uploaded {total:,} bytes in {chunk:,}-byte chunks")


def check_activity_log(api: httpx.Client, pid: str, order_id: str, buyer_name: str) -> None:
    """The API logged this listing's steps. In gcp mode the transcode entries come from Pub/Sub and may lag, so
    only the steps written inside our own requests are required."""
    r = api.get(path("listLogs"), params={"product_id": pid})
    if r.status_code != 200:
        fail(f"activity log: HTTP {r.status_code} {r.text[:CFG.error_text_chars]}")
    items = r.json()["items"]
    events = {e["event"] for e in items}
    missing = set(CFG.log_events) - events
    if missing:
        fail(f"activity log for {pid} lacks {sorted(missing)}; has {sorted(events)}")
    if not any(e["event"] == "order_placed" and e["order_id"] == order_id for e in items):
        fail(f"activity log has no order_placed entry for order {order_id}")
    if buyer_name in r.text:
        fail("activity log contains the buyer's name")
    ok(f"activity log: {len(items)} entries for the listing ({', '.join(e['event'] for e in reversed(items))})")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("base_url")
    ap.add_argument("--video", type=Path)
    ap.add_argument("--timeout", type=int, default=CFG.transcode_timeout_s,
                    help="seconds to wait for transcoding (default %(default)s)")
    a = ap.parse_args()
    base = a.base_url.rstrip("/")
    api = httpx.Client(base_url=f"{base}{API_SPEC['base_path']}", timeout=CFG.request_timeout_s)
    tag = f"{CFG.tag_prefix}{uuid.uuid4().hex[:6]}"
    listing = CFG.listing

    print(f"Smoke test against {base}")
    health = httpx.get(f"{base}{path('health')}", timeout=CFG.request_timeout_s).json()
    ok(f"health: mode={health['mode']}")

    policy = api.get(path("getUploadPolicy")).json()
    ok(f"upload policy: max {policy['max_duration_seconds']} s, chunk {policy['chunk_size_bytes']:,} bytes")

    r = api.post(path("createProduct"), json={"title": listing.title, "description": listing.description,
                                              "price": listing.price, "tags": [tag, *listing.tags],
                                              "artisan_name": listing.artisan_name})
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
        product = api.get(path("getProduct", product_id=pid)).json()
        if product["video_status"] in ("ready", "failed"):
            break
        if time.monotonic() > deadline:
            fail(f"still {product['video_status']} after {a.timeout} s")
        time.sleep(CFG.poll_every_s)
    if product["video_status"] != "ready":
        fail("transcoding failed")
    ok(f"video ready: {product['hls_url']}")

    manifest = httpx.get(product["hls_url"], timeout=CFG.request_timeout_s)
    if manifest.status_code != 200 or "#EXTM3U" not in manifest.text:
        fail(f"manifest not playable: HTTP {manifest.status_code}")
    ok(f"manifest served ({len(manifest.text.splitlines())} lines, cache: {manifest.headers.get('cache-control')})")

    page = api.get(path("listProducts"), params={"q": CFG.search, "tag": tag}).json()
    if [p["id"] for p in page["items"]] != [pid]:
        fail(f"search did not find exactly the new product: {page}")
    ok("search by keyword + tag finds it")

    buyer = CFG.order
    order = api.post(path("createOrder"), json={"product_id": pid, "buyer_name": buyer.buyer_name,
                                                "quantity": buyer.quantity}).json()
    if order.get("status") != "placed" or order.get("total") != listing.price * buyer.quantity:
        fail(f"order: {order}")
    ok(f"order {order['id']} placed, total {order['currency']} {order['total']}")

    again = api.get(path("getOrder", order_id=order["id"])).json()
    if again != order:
        fail(f"order read back differs: {again}")
    ok("order reads back by id (Your orders after a restart)")

    check_activity_log(api, pid, order["id"], buyer.buyer_name)
    print("PASS")


if __name__ == "__main__":
    main()
