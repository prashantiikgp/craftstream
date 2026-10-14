"""Measure a video's length with ffprobe. Reads only the container headers, so it is fast even over HTTP.
The time limit and the error text cap come from media/ingest.yml (ingest_engine).
"""

from __future__ import annotations

import subprocess

from app.core.errors import UnreadableVideo
from app.domain.media import ingest_engine


def probe_duration(source: str, headers: str | None = None, timeout_seconds: int | None = None) -> float:
    """Duration in seconds of a local path or URL; raises UnreadableVideo if it isn't a measurable video."""
    timeout_seconds = timeout_seconds or ingest_engine.probe_timeout_seconds()
    cmd = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1"]
    if headers:
        cmd += ["-headers", headers]
    try:
        out = subprocess.run([*cmd, source], capture_output=True, text=True, timeout=timeout_seconds,
                             check=True).stdout.strip()
    except subprocess.CalledProcessError as e:
        raise UnreadableVideo(ingest_engine.error_text(e.stderr or "", "ffprobe failed")) from e
    except subprocess.TimeoutExpired as e:
        raise UnreadableVideo(f"ffprobe took over {timeout_seconds} s") from e
    try:
        seconds = float(out)
    except ValueError as e:
        raise UnreadableVideo(f"no duration in the file ({out or 'empty'})") from e
    if not seconds > 0:
        raise UnreadableVideo("zero-length video")
    return seconds
