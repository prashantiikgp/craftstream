"""Shape of config/media/video_lifecycle.yml: the video states, the events between them and what each allows."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

# The events the media service fires. The YAML decides which state each one leads to.
Event = Literal["upload_unreadable", "transcode_started", "transcode_succeeded", "transcode_failed"]


class Transition(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    event: Event
    from_: list[str] = Field(alias="from", min_length=1)
    to: str


class VideoLifecycleRules(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True, populate_by_name=True)

    states: list[str] = Field(min_length=1)
    initial: str
    transitions: list[Transition] = Field(min_length=1)
    transcoder_results: dict[str, Event] = Field(min_length=1)
    listable: str
    orderable: str
    playable: str

    @model_validator(mode="after")
    def _known_states_and_events(self) -> VideoLifecycleRules:
        known = set(self.states)
        if len(known) != len(self.states):
            raise ValueError("states must not repeat")
        used = [self.initial, self.listable, self.orderable, self.playable]
        used += [s for t in self.transitions for s in (*t.from_, t.to)]
        unknown = sorted({s for s in used if s not in known})
        if unknown:
            raise ValueError(f"unknown states {unknown}; states are {self.states}")
        pairs = [(t.event, s) for t in self.transitions for s in t.from_]
        if len(pairs) != len(set(pairs)):
            raise ValueError("an event may lead out of a state only once")
        fired = {t.event for t in self.transitions}
        orphans = sorted(set(self.transcoder_results.values()) - fired)
        if orphans:
            raise ValueError(f"transcoder_results fire events with no transition: {orphans}")
        return self
