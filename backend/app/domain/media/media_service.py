"""Media: hand out upload targets, start transcoding when an upload lands, record the result.

Storage and Transcoder are ports: GCP implementations live in infra/gcp/, local fakes in infra/local/.
The app factory picks one set based on CRAFTSTREAM_MODE; this service never checks the mode.
"""

from __future__ import annotations

from typing import Protocol

from app.core.errors import UnreadableVideo
from app.db.repositories.product_repo import ProductRepo
from app.domain.media import storage_layout_engine, upload_policy_engine
from app.domain.media import video_lifecycle_engine as lifecycle
from app.domain.platform.activity_log_service import ActivityLogService
from app.generated.models import Product, UploadPolicy, UploadTicket
from app.schemas.media.video_lifecycle_schema import Event


class Storage(Protocol):
    def upload_url(self, product_id: str, origin: str | None, api_base_url: str) -> str: ...
    def hls_url(self, product_id: str) -> str: ...
    def thumbnail_url(self, product_id: str) -> str | None: ...
    def duration_seconds(self, product_id: str) -> float | None: ...  # None: unknown; raises UnreadableVideo
    def finalize_media(self, product_id: str) -> None: ...


class Transcoder(Protocol):
    completes_immediately: bool  # True for the local fake: no completion callback will come

    def submit(self, product_id: str, max_duration_seconds: int | None) -> str: ...  # None: keep it all
    def product_id_for_job(self, job_name: str) -> str | None: ...


class MediaService:
    def __init__(self, products: ProductRepo, storage: Storage, transcoder: Transcoder,
                 activity: ActivityLogService) -> None:
        self._products, self._storage, self._transcoder = products, storage, transcoder
        self._activity = activity

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
        """A file landed in the uploads bucket. Only raw-video objects (storage_layout.yml) are ours."""
        product_id = storage_layout_engine.product_id_from_object(object_name)
        if product_id:
            self.on_uploaded(product_id)

    def on_uploaded(self, product_id: str) -> None:
        """The raw video landed in storage. Safe to call twice (events can be redelivered)."""
        product = self._products.get(product_id)
        if product is None or lifecycle.next_state(product.video_status, "transcode_started") is None:
            self._activity.record("video_event_ignored", product_id=product_id, event="transcode_started",
                                  state=product.video_status if product else None)
            return
        self._activity.record("upload_received", product_id=product_id)
        try:
            duration = self._storage.duration_seconds(product_id)
        except UnreadableVideo as e:
            if self._move(product_id, product.video_status, "upload_unreadable"):
                self._activity.record("upload_unreadable", product_id=product_id, reason=str(e))
            return
        cap = upload_policy_engine.transcode_cap(duration)
        job = self._transcoder.submit(product_id, cap)
        state = self._move(product_id, product.video_status, "transcode_started", job)
        if state:
            self._activity.record("transcode_submitted", product_id=product_id, seconds=duration,
                                  cut_at_seconds=cap, job=job)
        if self._transcoder.completes_immediately and state:
            self._finish(product_id, state, "transcode_succeeded", job)

    def on_transcoded(self, job_name: str, state: str) -> None:
        """A transcode job changed state; only the final ones (video_lifecycle.yml) change the product."""
        event = lifecycle.transcoder_event(state)
        if event is None:
            return
        product_id = self._transcoder.product_id_for_job(job_name)
        product = self._products.get(product_id) if product_id else None
        if product is None:
            self._activity.record("video_event_ignored", product_id=product_id, event=event, job=job_name)
            return
        self._finish(product.id, product.video_status, event, job_name)

    def _finish(self, product_id: str, current: str, event: Event, job: str) -> None:
        """A transcode ended: move the video on and log transcode_succeeded / transcode_failed."""
        if self._move(product_id, current, event, job):
            self._activity.record(event, product_id=product_id, job=job)

    def _move(self, product_id: str, current: str, event: Event, job: str | None = None) -> str | None:
        """Apply `event` to the product's video; returns the new state, or None if the event doesn't apply."""
        state = lifecycle.next_state(current, event)
        if state is None:
            self._activity.record("video_event_ignored", product_id=product_id, event=event, state=current, job=job)
        elif lifecycle.is_playable(state):
            self._storage.finalize_media(product_id)
            self._products.update_video(product_id, state, self._storage.hls_url(product_id),
                                        self._storage.thumbnail_url(product_id))
        else:
            self._products.update_video(product_id, state)
        return state
