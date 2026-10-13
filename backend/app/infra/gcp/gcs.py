"""Video upload URLs and object paths.

The app uploads the raw video straight to Cloud Storage (not through our API), using a
*resumable upload session*: if the network drops, the app asks GCS how many bytes arrived
and continues from there. This is what makes large files on shaky networks possible.
"""

from __future__ import annotations

import re

from app.core.settings import settings

_RAW_OBJECT = re.compile(r"^raw/(?P<product_id>[A-Za-z0-9_-]+)/source$")


def raw_object_name(product_id: str) -> str:
    return f"raw/{product_id}/source"


def product_id_from_object(object_name: str) -> str | None:
    """`raw/<id>/source` -> `<id>`; anything else (e.g. other uploads) -> None."""
    m = _RAW_OBJECT.match(object_name)
    return m["product_id"] if m else None


def create_resumable_upload_url(product_id: str, origin: str | None = None, local_base_url: str = "") -> str:
    if settings.mode != "gcp":
        # Local mode: the API's fake upload target, which speaks the same resumable protocol.
        return f"{local_base_url.rstrip('/')}/local-upload/{product_id}"

    from google.cloud import storage  # imported lazily so local mode needs no GCP libs

    blob = storage.Client(project=settings.gcp_project).bucket(settings.upload_bucket).blob(
        raw_object_name(product_id)
    )
    # `origin` is required for browser (Flutter web) uploads so GCS sends CORS headers.
    return blob.create_resumable_upload_session(origin=origin)


def hls_url(product_id: str) -> str:
    return f"https://storage.googleapis.com/{settings.media_bucket}/hls/{product_id}/manifest.m3u8"


def thumbnail_url(product_id: str) -> str:
    # The Transcoder sprite sheet with totalCount=1 writes a single image named <prefix>0000000000.jpeg.
    return f"https://storage.googleapis.com/{settings.media_bucket}/hls/{product_id}/thumb0000000000.jpeg"
