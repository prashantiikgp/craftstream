"""Local stand-in for Cloud Storage: a fake resumable upload target and a public sample HLS stream.

The fake speaks the same resumable protocol as GCS, so the app's uploader is exercised for real:
  PUT with `Content-Range: bytes <start>-<end>/<total>`  -> 308 + `Range: bytes=0-<last byte>` until done
  PUT with `Content-Range: bytes */<total>` (empty)       -> "how much arrived?" (308 + Range, or 200 if done)
  PUT without Content-Range                              -> whole file in one go, done
Bytes are counted, not kept.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from app.domain.media import storage_layout_engine as layout

_CONTENT_RANGE = re.compile(r"bytes (?:(?P<start>\d+)-(?P<end>\d+)|\*)/(?P<total>\d+|\*)")


@dataclass(frozen=True)
class UploadProgress:
    complete: bool
    received: int  # bytes received so far (contiguous from 0)

    @property
    def range_header(self) -> dict[str, str]:
        return {"Range": f"bytes=0-{self.received - 1}"} if self.received else {}


class LocalStorage:
    def __init__(self) -> None:
        self._received: dict[str, int] = {}

    def upload_url(self, product_id: str, origin: str | None, api_base_url: str) -> str:
        return api_base_url.rstrip("/") + layout.local_upload_path(product_id)

    def duration_seconds(self, product_id: str) -> float | None:
        return None  # bytes are counted, not kept, so the length is unknown

    def hls_url(self, product_id: str) -> str:
        return layout.local_sample_stream()  # one public sample stream for every product

    def thumbnail_url(self, product_id: str) -> str | None:
        return None

    def finalize_media(self, product_id: str) -> None:
        pass  # the sample stream is not ours

    def receive(self, product_id: str, content_range: str | None, nbytes: int) -> UploadProgress:
        m = _CONTENT_RANGE.fullmatch(content_range or "")
        if m is None:  # single PUT with the whole file
            self._received.pop(product_id, None)
            return UploadProgress(complete=True, received=nbytes)

        so_far = self._received.get(product_id, 0)
        if m["end"] is not None:
            if int(m["start"]) > so_far:
                return UploadProgress(complete=False, received=so_far)  # a gap: ignore, client resumes from Range
            so_far = max(so_far, int(m["end"]) + 1)
        self._received[product_id] = so_far

        if m["total"] != "*" and so_far >= int(m["total"]):
            self._received.pop(product_id, None)
            return UploadProgress(complete=True, received=so_far)
        return UploadProgress(complete=False, received=so_far)
