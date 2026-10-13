"""CraftStream API. Routes must match models/endpoints.yml (enforced by tests).

Still one file on purpose: phase B1 splits it into api/routers/* + domain/*/<domain>_service.py.
"""

from __future__ import annotations

import base64
import json
import re
from collections import Counter

from fastapi import FastAPI, Query, Request, Response
from fastapi.middleware.cors import CORSMiddleware

from app.core.errors import DomainError, NotFound, install_error_handlers
from app.core.settings import settings
from app.db.repositories.repository import FirestoreRepo, InMemoryRepo, Repo, new_id, now, search_tokens
from app.domain.media import upload_policy_engine
from app.generated.models import (
    Order,
    OrderCreate,
    Product,
    ProductCreate,
    ProductPage,
    ProductSummary,
    TagList,
    UploadPolicy,
    UploadTicket,
)
from app.infra.gcp.gcs import create_resumable_upload_url, hls_url, product_id_from_object, thumbnail_url

API = "/api/v1"
# Moves to config/catalog/search.yml in B2.
DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE = 20, 50
LOCAL_SAMPLE_HLS = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"  # public sample stream for local mode

app = FastAPI(title="CraftStream API", version="0.2.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins.split(","),
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Range"],  # the resumable uploader reads it from 308 responses
)
install_error_handlers(app)

repo: Repo = FirestoreRepo(settings.gcp_project) if settings.mode == "gcp" else InMemoryRepo()


# ---------------------------------------------------------------- media pipeline

def start_transcoding(product: Product) -> None:
    """Kick off transcoding for this product's raw upload.

    Local mode marks the video ready immediately so the whole flow can be tested without GCP.
    """
    if settings.mode == "gcp":
        from app.infra.gcp.transcoder import submit_job

        submit_job(product.id)
        product.video_status = "processing"
    else:
        product.video_status = "ready"
        product.hls_url = LOCAL_SAMPLE_HLS


def on_uploaded(product_id: str) -> None:
    product = repo.get_product(product_id)
    if product is None or product.video_status != "awaiting_upload":
        return  # unknown object or a duplicate event: nothing to do
    start_transcoding(product)
    repo.save_product(product)


def on_transcoded(product_id: str, succeeded: bool) -> None:
    product = repo.get_product(product_id)
    if product is None:
        return
    product.video_status = "ready" if succeeded else "failed"
    product.hls_url = hls_url(product_id) if succeeded else None
    product.thumbnail_url = thumbnail_url(product_id) if succeeded else None
    repo.save_product(product)


# ---------------------------------------------------------------- public API

def _get_product(product_id: str) -> Product:
    product = repo.get_product(product_id)
    if not product:
        raise NotFound(f"Product {product_id} not found")
    return product


@app.post(f"{API}/products", response_model=UploadTicket, status_code=201)
def create_product(body: ProductCreate, request: Request) -> UploadTicket:
    product = Product(id=new_id(), created_at=now(), **body.model_dump())
    repo.save_product(product)
    url = create_resumable_upload_url(product.id, origin=request.headers.get("origin"),
                                      local_base_url=str(request.base_url))
    return UploadTicket(product=product, upload_url=url, upload_method="PUT",
                        chunk_size_bytes=upload_policy_engine.chunk_size_bytes())


@app.get(f"{API}/products", response_model=ProductPage, status_code=200)
def list_products(
    q: str | None = Query(None),
    tag: str | None = Query(None),
    cursor: str | None = Query(None),
    limit: int = Query(DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE),
) -> ProductPage:
    results = [p for p in repo.list_products() if p.video_status == "ready"]
    if tag:
        results = [p for p in results if tag.lower() in (t.lower() for t in p.tags)]
    if q:
        words = q.lower().split()
        results = [p for p in results if all(any(tok.startswith(w) for tok in search_tokens(p)) for w in words)]
    if cursor:
        ids = [p.id for p in results]
        results = results[ids.index(cursor) + 1:] if cursor in ids else []
    page = results[:limit]
    next_cursor = page[-1].id if len(results) > limit else None
    items = [ProductSummary(**p.model_dump(include=set(ProductSummary.model_fields))) for p in page]
    return ProductPage(items=items, next_cursor=next_cursor)


@app.get(f"{API}/products/{{product_id}}", response_model=Product, status_code=200)
def get_product(product_id: str) -> Product:
    return _get_product(product_id)


@app.get(f"{API}/tags", response_model=TagList, status_code=200)
def list_tags() -> TagList:
    counts = Counter(t.lower() for p in repo.list_products() if p.video_status == "ready" for t in p.tags)
    return TagList(tags=[t for t, _ in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))])


@app.get(f"{API}/upload-policy", response_model=UploadPolicy, status_code=200)
def get_upload_policy() -> UploadPolicy:
    rules = upload_policy_engine.load_upload_policy_rules()
    return UploadPolicy(max_duration_seconds=rules.max_duration_seconds,
                        allowed_mime_types=list(rules.allowed_mime_types),
                        chunk_size_bytes=upload_policy_engine.chunk_size_bytes(rules))


@app.post(f"{API}/orders", response_model=Order, status_code=201)
def create_order(body: OrderCreate) -> Order:
    product = _get_product(body.product_id)
    if product.video_status != "ready":
        raise DomainError("This product is not available yet.")
    # Total rounding moves to config/orders/order_rules.yml in B2.
    order = Order(id=new_id(), created_at=now(), total=round(product.price * body.quantity, 2),
                  currency=product.currency, **body.model_dump())
    repo.save_order(order)
    return order


# ---------------------------------------------------------------- internal (not in the Dart client)

@app.get("/healthz", status_code=200, include_in_schema=False)
def health() -> dict:
    return {"ok": True, "mode": settings.mode}


_CONTENT_RANGE = re.compile(r"bytes (?:(?P<start>\d+)-(?P<end>\d+)|\*)/(?P<total>\d+|\*)")
_local_received: dict[str, int] = {}

if settings.mode == "local":

    @app.put("/local-upload/{product_id}", status_code=200, include_in_schema=False)
    async def local_upload(product_id: str, request: Request) -> Response:
        """Fake GCS resumable target: accepts Content-Range chunks, answers 308 + Range until the last one."""
        _get_product(product_id)
        received = 0
        async for chunk in request.stream():  # discard the bytes; only count them
            received += len(chunk)
        m = _CONTENT_RANGE.fullmatch(request.headers.get("content-range", ""))
        if m and m["total"] != "*":
            total = int(m["total"])
            end = int(m["end"]) if m["end"] is not None else _local_received.get(product_id, 0) - 1
            _local_received[product_id] = max(_local_received.get(product_id, 0), end + 1)
            if _local_received[product_id] < total:
                headers = {"Range": f"bytes=0-{_local_received[product_id] - 1}"} if _local_received[product_id] else {}
                return Response(status_code=308, headers=headers)
        elif m:  # "bytes */*" or a chunk of unknown total: report progress, not done yet
            _local_received[product_id] = _local_received.get(product_id, 0) + received
            return Response(status_code=308, headers={"Range": f"bytes=0-{_local_received[product_id] - 1}"})
        _local_received.pop(product_id, None)
        on_uploaded(product_id)
        return Response(status_code=200)


@app.post("/internal/media/uploaded", status_code=204, include_in_schema=False)
async def media_uploaded(request: Request) -> Response:
    """Eventarc delivers the GCS object (finalized) as the JSON body: {"bucket": ..., "name": ...}."""
    # TODO(B4): verify the Eventarc OIDC token before trusting the body.
    event = await request.json()
    product_id = product_id_from_object(event.get("name", ""))
    if product_id:
        on_uploaded(product_id)
    return Response(status_code=204)


@app.post("/internal/media/transcoded", status_code=204, include_in_schema=False)
async def media_transcoded(request: Request) -> Response:
    """Pub/Sub push: message.data is base64 JSON {"job": {"name": ..., "state": "SUCCEEDED" | "FAILED"}}."""
    # TODO(B4): verify the Pub/Sub OIDC token before trusting the body.
    envelope = await request.json()
    data = json.loads(base64.b64decode(envelope["message"]["data"]))
    job = data.get("job", {})
    if job.get("state") in ("SUCCEEDED", "FAILED"):
        from app.infra.gcp import transcoder

        product_id = transcoder.product_id_for_job(job["name"])
        if product_id:
            on_transcoded(product_id, succeeded=job["state"] == "SUCCEEDED")
    return Response(status_code=204)
