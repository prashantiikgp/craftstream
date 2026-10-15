"""Upload endpoints: the policy the app checks first, and (local mode only) the fake upload target.
Routes, and which mode serves the fake target, come from models/endpoints.yml."""

from __future__ import annotations

from fastapi import Request, Response

from app.api.deps import CatalogDep, ContainerDep, MediaDep
from app.api.endpoints import EndpointHandlers
from app.generated.models import UploadPolicy

endpoints = EndpointHandlers()


@endpoints.handler("getUploadPolicy")
def get_upload_policy(media: MediaDep) -> UploadPolicy:
    return media.upload_policy()


@endpoints.handler("localUpload")
async def local_upload(product_id: str, request: Request, c: ContainerDep, catalog: CatalogDep,
                       media: MediaDep) -> Response:
    """Fake GCS resumable target (see infra/local/local_storage.py). Only mounted in local mode."""
    catalog.get(product_id)  # 404 for unknown products
    received = 0
    async for chunk in request.stream():  # count the bytes, don't keep them
        received += len(chunk)
    progress = c.storage.receive(product_id, request.headers.get("content-range"), received)
    if not progress.complete:
        return Response(status_code=308, headers=progress.range_header)
    media.on_uploaded(product_id)
    return Response(status_code=200)
