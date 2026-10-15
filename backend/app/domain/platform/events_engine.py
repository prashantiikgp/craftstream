"""Reading the GCP callbacks: the accepted Eventarc event types and the Pub/Sub push envelope.
Pure logic over EventsRules; api/routers/internal.py serves the routes (declared in models/endpoints.yml).
"""

from __future__ import annotations

import base64
import binascii
import json
from collections.abc import Mapping

from app.domain.platform.events_loader import load_events_rules
from app.schemas.platform.events_schema import EventsRules, Messages


class NotAJobResult(ValueError):
    """The Pub/Sub push body doesn't hold a Transcoder job result."""


def _rules(rules: EventsRules | None) -> EventsRules:
    return rules or load_events_rules()


def messages(rules: EventsRules | None = None) -> Messages:
    return _rules(rules).messages


def event_type_header(rules: EventsRules | None = None) -> str:
    return _rules(rules).upload_finalized.event_type_header


def accepts_event_type(event_type: str | None, rules: EventsRules | None = None) -> bool:
    """No event type (local mode, tests) is accepted; otherwise it must be one we handle."""
    return event_type is None or event_type in _rules(rules).upload_finalized.accepted_event_types


def object_name(event: Mapping, rules: EventsRules | None = None) -> str:
    """The object name from an object-finalized event body ('' if it has none)."""
    return str(event.get(_rules(rules).upload_finalized.object_name_key, ""))


def transcoder_job(envelope: Mapping, rules: EventsRules | None = None) -> tuple[str, str]:
    """(job name, job state) from a Pub/Sub push body; raises NotAJobResult if it isn't one."""
    t = _rules(rules).transcode_result
    try:
        payload = envelope
        for key in t.envelope_keys:
            payload = payload[key]
        job = json.loads(base64.b64decode(payload))[t.job_key]
        return job[t.job_name_key], job.get(t.job_state_key, "")
    except (KeyError, TypeError, ValueError, AttributeError, binascii.Error) as e:
        raise NotAJobResult(str(e)) from e
