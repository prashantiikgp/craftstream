"""Video upload URLs.

The app uploads the raw video straight to Cloud Storage (not through our API), using a
*resumable upload session*: if the network drops, the app asks GCS how many bytes arrived
and continues from there. This is what makes large files on shaky networks possible.
"""

from __future__ import annotations

from .config import settings


def raw_object_name(product_id: str) -> str:
    return f"raw/{product_id}/source"


def create_resumable_upload_url(product_id: str, origin: str | None = None) -> str:
    if settings.mode != "gcp":
        # Local mode: no real upload target. The app can skip the upload step.
        return f"http://localhost:8000/local-upload/{product_id}"

    from google.cloud import storage

    blob = storage.Client(project=settings.gcp_project).bucket(settings.upload_bucket).blob(
        raw_object_name(product_id)
    )
    # `origin` is required for browser (Flutter web) uploads so GCS sends CORS headers.
    return blob.create_resumable_upload_session(content_type="video/*", origin=origin)


def hls_url(product_id: str) -> str:
    return f"https://storage.googleapis.com/{settings.media_bucket}/hls/{product_id}/manifest.m3u8"
