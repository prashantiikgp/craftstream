"""Media: hand out upload targets, start transcoding when an upload lands, record the result.

Storage and Transcoder are ports: GCP implementations live in infra/gcp/, local fakes in infra/local/.
The app factory picks one set based on CRAFTSTREAM_MODE; this service never checks the mode.
"""

from __future__ import annotations

import logging
from typing import Protocol

from app.db.repositories.product_repo import ProductRepo
from app.domain.media import upload_policy_engine
from app.generated.models import Product, UploadPolicy, UploadTicket
from app.infra.gcp.gcs import product_id_from_object

log = logging.getLogger(__name__)


class Storage(Protocol):
    def upload_url(self, product_id: str, origin: str | None, api_base_url: str) -> str: ...
    def hls_url(self, product_id: str) -> str: ...
    def thumbnail_url(self, product_id: str) -> str | None: ...
    def finalize_media(self, product_id: str) -> None: ...


class Transcoder(Protocol):
    completes_immediately: bool  # True for the local fake: no completion callback will come

    def submit(self, product_id: str, max_duration_seconds: int) -> str: ...
    def product_id_for_job(self, job_name: str) -> str | None: ...


class MediaService:
    def __init__(self, products: ProductRepo, storage: Storage, transcoder: Transcoder) -> None:
        self._products, self._storage, self._transcoder = products, storage, transcoder

    def upload_ticket(self, product: Product, origin: str | None, api_base_url: str) -> UploadTicket:
        return UploadTicket(
            product=product,
            upload_url=self._storage.upload_url(product.id, origin, api_base_url),
            upload_method="PUT",
            chunk_size_bytes=upload_policy_engine.chunk_size_bytes(),
        )

    def upload_policy(self) -> UploadPolicy:
        rules = upload_policy_engine.load_upload_policy_rules()
        return UploadPolicy(max_duration_seconds=rules.max_duration_seconds,
                            allowed_mime_types=list(rules.allowed_mime_types),
                            chunk_size_bytes=upload_policy_engine.chunk_size_bytes(rules))

    def on_object_finalized(self, object_name: str) -> None:
        """A file landed in the uploads bucket. Only `raw/<product_id>/source` objects are ours."""
        product_id = product_id_from_object(object_name)
        if product_id:
            self.on_uploaded(product_id)

    def on_uploaded(self, product_id: str) -> None:
        """The raw video landed in storage. Safe to call twice (events can be redelivered)."""
        product = self._products.get(product_id)
        if product is None or product.video_status != "awaiting_upload":
            log.info("upload event ignored", extra={"product_id": product_id})
            return
        job = self._transcoder.submit(product_id, upload_policy_engine.max_duration_seconds())
        self._products.update_video(product_id, "processing")
        log.info("transcode submitted", extra={"product_id": product_id, "job": job})
        if self._transcoder.completes_immediately:
            self._finish(product_id, succeeded=True)

    def on_transcoded(self, job_name: str, state: str) -> None:
        """A transcode job reached a final state (SUCCEEDED / FAILED); other states are ignored."""
        if state not in ("SUCCEEDED", "FAILED"):
            return
        product_id = self._transcoder.product_id_for_job(job_name)
        if product_id is None or self._products.get(product_id) is None:
            log.warning("transcode result for unknown product", extra={"job": job_name})
            return
        self._finish(product_id, succeeded=state == "SUCCEEDED")

    def _finish(self, product_id: str, succeeded: bool) -> None:
        if succeeded:
            self._storage.finalize_media(product_id)
            self._products.update_video(product_id, "ready", self._storage.hls_url(product_id),
                                        self._storage.thumbnail_url(product_id))
        else:
            self._products.update_video(product_id, "failed")
        log.info("transcode finished", extra={"product_id": product_id, "succeeded": succeeded})
