"""Callbacks from GCP. Not in the Dart client or the public docs.

    Eventarc (GCS object finalized) -> POST /internal/media/uploaded    body: the object {"bucket", "name", ...}
    Pub/Sub push (Transcoder job)   -> POST /internal/media/transcoded  body: {"message": {"data": base64 JSON}}
"""

from __future__ import annotations

import base64
import binascii
import json

from fastapi import APIRouter, Request, Response

from app.api.deps import MediaDep
from app.core.errors import DomainError

router = APIRouter(prefix="/internal/media", include_in_schema=False)


async def _json(request: Request) -> dict:
    try:
        body = await request.json()
    except ValueError as e:
        raise DomainError("Body is not JSON.") from e
    if not isinstance(body, dict):
        raise DomainError("Body must be a JSON object.")
    return body


@router.post("/uploaded", status_code=204)
async def media_uploaded(request: Request, media: MediaDep) -> Response:
    # TODO(B4): verify the Eventarc OIDC token before trusting the body.
    event = await _json(request)
    media.on_object_finalized(str(event.get("name", "")))
    return Response(status_code=204)


@router.post("/transcoded", status_code=204)
async def media_transcoded(request: Request, media: MediaDep) -> Response:
    # TODO(B4): verify the Pub/Sub OIDC token before trusting the body.
    envelope = await _json(request)
    try:
        data = json.loads(base64.b64decode(envelope["message"]["data"]))
        job = data["job"]
        name, state = job["name"], job.get("state", "")
    except (KeyError, TypeError, ValueError, binascii.Error) as e:
        raise DomainError("Not a Transcoder job notification.") from e
    media.on_transcoded(name, state)
    return Response(status_code=204)
