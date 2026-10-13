"""Measure a video's length with ffprobe. Reads only the container headers, so it is fast even over HTTP."""

from __future__ import annotations

import subprocess

from app.core.errors import UnreadableVideo


def probe_duration(source: str, headers: str | None = None, timeout_seconds: int = 60) -> float:
    """Duration in seconds of a local path or URL; raises UnreadableVideo if it isn't a measurable video."""
    cmd = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1"]
    if headers:
        cmd += ["-headers", headers]
    try:
        out = subprocess.run([*cmd, source], capture_output=True, text=True, timeout=timeout_seconds,
                             check=True).stdout.strip()
    except subprocess.CalledProcessError as e:
        raise UnreadableVideo(e.stderr.strip()[-200:] or "ffprobe failed") from e
    except subprocess.TimeoutExpired as e:
        raise UnreadableVideo(f"ffprobe took over {timeout_seconds} s") from e
    try:
        seconds = float(out)
    except ValueError as e:
        raise UnreadableVideo(f"no duration in the file ({out or 'empty'})") from e
    if not seconds > 0:
        raise UnreadableVideo("zero-length video")
    return seconds
