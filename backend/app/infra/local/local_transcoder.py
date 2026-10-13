"""Local stand-in for the Transcoder API: every job "finishes" instantly and successfully."""

from __future__ import annotations


class LocalTranscoder:
    completes_immediately = True

    def __init__(self) -> None:
        self._jobs: dict[str, str] = {}

    def submit(self, product_id: str, max_duration_seconds: int | None) -> str:
        name = f"local/jobs/{product_id}"
        self._jobs[name] = product_id
        return name

    def product_id_for_job(self, job_name: str) -> str | None:
        return self._jobs.get(job_name)
