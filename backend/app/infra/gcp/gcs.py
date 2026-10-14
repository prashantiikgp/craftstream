"""Cloud Storage: resumable upload sessions for raw videos, and public URLs for the HLS output.

The app uploads the raw video straight to Cloud Storage (not through our API), using a
*resumable upload session*: if the network drops, the app asks GCS how many bytes arrived
and continues from there. This is what makes large files on shaky networks possible.
Object names, URLs and cache headers come from media/storage_layout.yml (storage_layout_engine).
"""

from __future__ import annotations

from app.domain.media import storage_layout_engine as layout


class GcsStorage:
    def __init__(self, project: str, upload_bucket: str, media_bucket: str) -> None:
        self._project, self._upload_bucket, self._media_bucket = project, upload_bucket, media_bucket

    def upload_url(self, product_id: str, origin: str | None, api_base_url: str) -> str:
        from google.cloud import storage  # imported lazily so local mode needs no GCP libs

        blob = storage.Client(project=self._project).bucket(self._upload_bucket).blob(layout.raw_object(product_id))
        # `origin` is required for browser (Flutter web) uploads so GCS sends CORS headers.
        return blob.create_resumable_upload_session(origin=origin)

    def duration_seconds(self, product_id: str) -> float | None:
        """Measure the raw upload in place: ffprobe reads its headers over HTTPS with our own access token."""
        import google.auth  # imported lazily so local mode needs no GCP libs
        from google.auth.transport.requests import Request

        from app.infra.ffprobe import probe_duration

        creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/devstorage.read_only"])
        creds.refresh(Request())
        url = layout.object_url(self._upload_bucket, layout.raw_object(product_id))
        return probe_duration(url, headers=f"Authorization: Bearer {creds.token}\r\n")

    def hls_url(self, product_id: str) -> str:
        return layout.object_url(self._media_bucket, layout.manifest_object(product_id))

    def finalize_media(self, product_id: str) -> None:
        """Mark the finished HLS files as cacheable (the Transcoder writes them with default headers)."""
        from google.cloud import storage

        cache_control = layout.hls_cache_control()
        bucket = storage.Client(project=self._project).bucket(self._media_bucket)
        for blob in bucket.list_blobs(prefix=layout.hls_prefix(product_id)):
            if blob.cache_control != cache_control:
                blob.cache_control = cache_control
                blob.patch()

    def thumbnail_url(self, product_id: str) -> str | None:
        return layout.object_url(self._media_bucket, layout.thumbnail_object(product_id))
