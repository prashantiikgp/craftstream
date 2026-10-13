"""Transcoder API: submit jobs built by ladder_engine and resolve finished jobs back to products."""

from __future__ import annotations

from app.domain.media.ladder_engine import build_job_config
from app.infra.gcp.gcs import raw_object_name


class GcpTranscoder:
    completes_immediately = False  # completion arrives later via Pub/Sub -> /internal/media/transcoded

    def __init__(self, project: str, region: str, upload_bucket: str, media_bucket: str) -> None:
        self._parent = f"projects/{project}/locations/{region}"
        self._upload_bucket, self._media_bucket = upload_bucket, media_bucket

    def submit(self, product_id: str, max_duration_seconds: int) -> str:
        """Start transcoding the product's raw upload; returns the job name. Completion arrives via Pub/Sub."""
        from google.cloud.video import transcoder_v1  # imported lazily so local mode needs no GCP libs

        config = build_job_config(
            input_uri=f"gs://{self._upload_bucket}/{raw_object_name(product_id)}",
            max_duration_seconds=max_duration_seconds,
        )
        job = transcoder_v1.Job(
            output_uri=f"gs://{self._media_bucket}/hls/{product_id}/",
            config=transcoder_v1.JobConfig(config),
            labels={"product_id": product_id},
        )
        # TODO(B4): set config.pubsub_destination so /internal/media/transcoded is called when done.
        return transcoder_v1.TranscoderServiceClient().create_job(parent=self._parent, job=job).name

    def product_id_for_job(self, job_name: str) -> str | None:
        """The Pub/Sub notification only names the job; the product id is in the job's labels."""
        from google.cloud.video import transcoder_v1

        return transcoder_v1.TranscoderServiceClient().get_job(name=job_name).labels.get("product_id")
