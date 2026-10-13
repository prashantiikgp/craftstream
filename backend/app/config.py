"""Settings, read from environment variables (see .env.example)."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    # "local" = in-memory database + no real GCS calls (for development and tests).
    # "gcp"   = Firestore + Cloud Storage + Transcoder API.
    mode: str = os.getenv("CRAFTSTREAM_MODE", "local")
    gcp_project: str = os.getenv("GCP_PROJECT", "")
    gcp_region: str = os.getenv("GCP_REGION", "asia-south1")
    upload_bucket: str = os.getenv("UPLOAD_BUCKET", "")    # raw artisan uploads
    media_bucket: str = os.getenv("MEDIA_BUCKET", "")      # HLS output, publicly readable
    cors_origins: str = os.getenv("CORS_ORIGINS", "*")


settings = Settings()
