"""Cloud Storage: resumable upload sessions for raw videos, and public URLs for the HLS output.

The app uploads the raw video straight to Cloud Storage (not through our API), using a
*resumable upload session*: if the network drops, the app asks GCS how many bytes arrived
and continues from there. This is what makes large files on shaky networks possible.
"""

from __future__ import annotations

import re

# HLS output never changes once written, so players and Google's edge may cache it for a year.
IMMUTABLE = "public, max-age=31536000, immutable"
_RAW_OBJECT = re.compile(r"^raw/(?P<product_id>[A-Za-z0-9_-]+)/source$")


def raw_object_name(product_id: str) -> str:
    return f"raw/{product_id}/source"


def product_id_from_object(object_name: str) -> str | None:
    """`raw/<id>/source` -> `<id>`; anything else (e.g. other uploads) -> None."""
    m = _RAW_OBJECT.match(object_name)
    return m["product_id"] if m else None


class GcsStorage:
    def __init__(self, project: str, upload_bucket: str, media_bucket: str) -> None:
        self._project, self._upload_bucket, self._media_bucket = project, upload_bucket, media_bucket

    def upload_url(self, product_id: str, origin: str | None, api_base_url: str) -> str:
        from google.cloud import storage  # imported lazily so local mode needs no GCP libs

        blob = storage.Client(project=self._project).bucket(self._upload_bucket).blob(raw_object_name(product_id))
        # `origin` is required for browser (Flutter web) uploads so GCS sends CORS headers.
        return blob.create_resumable_upload_session(origin=origin)

    def hls_url(self, product_id: str) -> str:
        return f"https://storage.googleapis.com/{self._media_bucket}/hls/{product_id}/manifest.m3u8"

    def finalize_media(self, product_id: str) -> None:
        """Mark the finished HLS files as cacheable (the Transcoder writes them with default headers)."""
        from google.cloud import storage

        bucket = storage.Client(project=self._project).bucket(self._media_bucket)
        for blob in bucket.list_blobs(prefix=f"hls/{product_id}/"):
            if blob.cache_control != IMMUTABLE:
                blob.cache_control = IMMUTABLE
                blob.patch()

    def thumbnail_url(self, product_id: str) -> str | None:
        # The Transcoder sprite sheet with totalCount=1 writes one image named <prefix>0000000000.jpeg.
        return f"https://storage.googleapis.com/{self._media_bucket}/hls/{product_id}/thumb0000000000.jpeg"
