"""CraftStream API. Routes must match specs/api/endpoints.yaml (enforced by tests)."""

from __future__ import annotations

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .generated.models import Order, OrderCreate, Product, ProductCreate, UploadTicket
from .repository import FirestoreRepo, InMemoryRepo, Repo, new_id, now, search_tokens
from .storage import create_resumable_upload_url, hls_url

API = "/api/v1"

app = FastAPI(title="CraftStream API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins.split(","),
    allow_methods=["*"],
    allow_headers=["*"],
)

repo: Repo = FirestoreRepo(settings.gcp_project) if settings.mode == "gcp" else InMemoryRepo()


def start_transcoding(product: Product) -> None:
    """Kick off the Transcoder API job for this product's raw upload.

    Local mode marks the video ready immediately so the UI flow can be tested end to end.
    """
    if settings.mode == "gcp":
        from transcoder.gcp_job import submit_job  # noqa: PLC0415

        submit_job(product.id)
        product.video_status = "processing"
    else:
        product.video_status = "ready"
        product.hls_url = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"  # public sample stream


@app.get("/healthz")
def health() -> dict:
    return {"ok": True, "mode": settings.mode}


@app.post(f"{API}/products", response_model=UploadTicket, status_code=201)
def create_product(body: ProductCreate, request: Request) -> UploadTicket:
    product = Product(id=new_id(), created_at=now(), **body.model_dump())
    repo.save_product(product)
    url = create_resumable_upload_url(product.id, origin=request.headers.get("origin"))
    return UploadTicket(product=product, upload_url=url, upload_method="PUT")


@app.get(f"{API}/products", response_model=list[Product])
def list_products(q: str | None = Query(None), tag: str | None = Query(None)) -> list[Product]:
    results = [p for p in repo.list_products() if p.video_status == "ready"]
    if tag:
        results = [p for p in results if tag.lower() in (t.lower() for t in p.tags)]
    if q:
        words = q.lower().split()
        results = [p for p in results if all(any(tok.startswith(w) for tok in search_tokens(p)) for w in words)]
    return results


@app.get(f"{API}/products/{{product_id}}", response_model=Product)
def get_product(product_id: str) -> Product:
    product = repo.get_product(product_id)
    if not product:
        raise HTTPException(404, "Product not found")
    return product


@app.post(f"{API}/products/{{product_id}}/upload-complete", response_model=Product)
def mark_upload_complete(product_id: str) -> Product:
    product = get_product(product_id)
    start_transcoding(product)
    repo.save_product(product)
    return product


@app.post(f"{API}/transcode-callback/{{product_id}}", include_in_schema=False)
def transcode_callback(product_id: str, succeeded: bool = True) -> dict:
    """Called (via Pub/Sub push) when the Transcoder job finishes."""
    product = get_product(product_id)
    product.video_status = "ready" if succeeded else "failed"
    product.hls_url = hls_url(product_id) if succeeded else None
    repo.save_product(product)
    return {"ok": True}


@app.post(f"{API}/orders", response_model=Order, status_code=201)
def create_order(body: OrderCreate) -> Order:
    product = get_product(body.product_id)
    order = Order(id=new_id(), created_at=now(), total=round(product.price * body.quantity, 2), **body.model_dump())
    repo.save_order(order)
    return order
