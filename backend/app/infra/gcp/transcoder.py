"""Transcoder API: submit jobs built by ladder_engine and resolve finished jobs back to products."""

from __future__ import annotations

import json

from app.domain.media import storage_layout_engine as layout
from app.domain.media.ladder_engine import build_job_config


def job_config_proto(config: dict):
    """build_job_config returns REST JSON (camelCase); proto-plus constructors only take snake_case fields."""
    from google.cloud.video import transcoder_v1

    return transcoder_v1.JobConfig.from_json(json.dumps(config))


class GcpTranscoder:
    completes_immediately = False  # completion arrives later via Pub/Sub (platform/events.yml)

    def __init__(self, project: str, region: str, upload_bucket: str, media_bucket: str, topic: str) -> None:
        self._parent = f"projects/{project}/locations/{region}"
        self._upload_bucket, self._media_bucket = upload_bucket, media_bucket
        self._topic = f"projects/{project}/topics/{topic}"

    def submit(self, product_id: str, max_duration_seconds: int | None) -> str:
        """Start transcoding the product's raw upload; returns the job name. Completion arrives via Pub/Sub."""
        from google.cloud.video import transcoder_v1  # imported lazily so local mode needs no GCP libs

        config = build_job_config(
            input_uri=layout.gcs_uri(self._upload_bucket, layout.raw_object(product_id)),
            max_duration_seconds=max_duration_seconds,
            pubsub_topic=self._topic,
        )
        job = transcoder_v1.Job(
            output_uri=layout.gcs_uri(self._media_bucket, layout.hls_prefix(product_id)),
            config=job_config_proto(config),
            labels={layout.job_label(): product_id},
        )
        return transcoder_v1.TranscoderServiceClient().create_job(parent=self._parent, job=job).name

    def product_id_for_job(self, job_name: str) -> str | None:
        """The Pub/Sub notification only names the job; the product id is in the job's labels."""
        from google.cloud.video import transcoder_v1

        return transcoder_v1.TranscoderServiceClient().get_job(name=job_name).labels.get(layout.job_label())
