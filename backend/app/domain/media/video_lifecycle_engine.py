"""The video state machine. Pure logic over VideoLifecycleRules.

    next_state(current, event)   -> the new state, or None when the event doesn't apply (ignore it)
    transcoder_event(job_state)  -> the event a finished Transcoder job fires, or None while it runs
"""

from __future__ import annotations

from app.domain.media.video_lifecycle_loader import load_video_lifecycle_rules
from app.schemas.media.video_lifecycle_schema import Event, VideoLifecycleRules


def _rules(rules: VideoLifecycleRules | None) -> VideoLifecycleRules:
    return rules or load_video_lifecycle_rules()


def initial_state(rules: VideoLifecycleRules | None = None) -> str:
    return _rules(rules).initial


def next_state(current: str, event: Event, rules: VideoLifecycleRules | None = None) -> str | None:
    for t in _rules(rules).transitions:
        if t.event == event and current in t.from_:
            return t.to
    return None


def transcoder_event(job_state: str, rules: VideoLifecycleRules | None = None) -> Event | None:
    return _rules(rules).transcoder_results.get(job_state)


def listable_state(rules: VideoLifecycleRules | None = None) -> str:
    return _rules(rules).listable


def is_orderable(state: str, rules: VideoLifecycleRules | None = None) -> bool:
    return state == _rules(rules).orderable


def is_playable(state: str, rules: VideoLifecycleRules | None = None) -> bool:
    return state == _rules(rules).playable
