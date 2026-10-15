"""Callbacks from GCP. Not in the Dart client or the public docs. Every call must carry a Google-signed
OIDC token from our Eventarc / Pub/Sub service account (verify_internal_caller); local mode allows all.
Paths come from `internal` in models/endpoints.yml, message formats from platform/events.yml (events_engine):

    Eventarc (GCS object finalized) -> mediaUploaded      body: the object {"bucket", "name", ...}
    Pub/Sub push (Transcoder job)   -> mediaTranscoded    body: {"message": {"data": base64 JSON}}
"""

from __future__ import annotations

import logging

from fastapi import Depends, Request, Response

from app.api.deps import MediaDep, verify_internal_caller
from app.api.endpoints import EndpointHandlers
from app.core.errors import DomainError
from app.domain.platform import events_engine as events

log = logging.getLogger(__name__)

endpoints = EndpointHandlers(dependencies=[Depends(verify_internal_caller)])


async def _json(request: Request) -> dict:
    try:
        body = await request.json()
    except ValueError as e:
        raise DomainError(events.messages().not_json) from e
    if not isinstance(body, dict):
        raise DomainError(events.messages().not_an_object)
    return body


@endpoints.handler("mediaUploaded")
async def media_uploaded(request: Request, media: MediaDep) -> Response:
    event_type = request.headers.get(events.event_type_header())
    if not events.accepts_event_type(event_type):
        log.info("event ignored", extra={"event_type": event_type})
        return Response(status_code=204)
    media.on_object_finalized(events.object_name(await _json(request)))
    return Response(status_code=204)


@endpoints.handler("mediaTranscoded")
async def media_transcoded(request: Request, media: MediaDep) -> Response:
    try:
        name, state = events.transcoder_job(await _json(request))
    except events.NotAJobResult as e:
        raise DomainError(events.messages().not_a_job_result) from e
    media.on_transcoded(name, state)
    return Response(status_code=204)
