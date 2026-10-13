"""Submit a Transcoder API job built by ladder_engine. Thin wrapper over the Google SDK."""

from __future__ import annotations

from app.core.settings import settings
from app.domain.media.ladder_engine import build_job_config
from app.infra.gcp.gcs import raw_object_name


def submit_job(product_id: str) -> str:
    from google.cloud.video import transcoder_v1  # imported lazily so local mode needs no GCP libs

    client = transcoder_v1.TranscoderServiceClient()
    job = transcoder_v1.Job(
        input_uri=f"gs://{settings.upload_bucket}/{raw_object_name(product_id)}",
        output_uri=f"gs://{settings.media_bucket}/hls/{product_id}/",
        config=transcoder_v1.JobConfig(build_job_config()),
        labels={"product_id": product_id},
    )
    # TODO(B4): set job.config.pubsub_destination so /internal/media/transcoded is called when done.
    result = client.create_job(parent=f"projects/{settings.gcp_project}/locations/{settings.gcp_region}", job=job)
    return result.name
