"""Submit and look up Transcoder API jobs. Thin wrapper over the Google SDK; the job itself comes from ladder_engine."""

from __future__ import annotations

from app.core.settings import settings
from app.domain.media.ladder_engine import build_job_config
from app.domain.media.upload_policy_engine import max_duration_seconds
from app.infra.gcp.gcs import raw_object_name


def submit_job(product_id: str) -> str:
    """Start transcoding the product's raw upload; returns the job name."""
    from google.cloud.video import transcoder_v1  # imported lazily so local mode needs no GCP libs

    client = transcoder_v1.TranscoderServiceClient()
    config = build_job_config(
        input_uri=f"gs://{settings.upload_bucket}/{raw_object_name(product_id)}",
        max_duration_seconds=max_duration_seconds(),
    )
    job = transcoder_v1.Job(
        output_uri=f"gs://{settings.media_bucket}/hls/{product_id}/",
        config=transcoder_v1.JobConfig(config),
        labels={"product_id": product_id},
    )
    # TODO(B4): set config.pubsub_destination so /internal/media/transcoded is called when done.
    result = client.create_job(parent=f"projects/{settings.gcp_project}/locations/{settings.gcp_region}", job=job)
    return result.name


def product_id_for_job(job_name: str) -> str | None:
    """The Pub/Sub notification only names the job; the product id is in the job's labels."""
    from google.cloud.video import transcoder_v1

    job = transcoder_v1.TranscoderServiceClient().get_job(name=job_name)
    return job.labels.get("product_id")
