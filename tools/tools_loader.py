"""Read tools/tools.yml: the defaults of the developer tools. Standard library + PyYAML, no backend imports.

    from tools_loader import load_tools_config
    cfg = load_tools_config().throttle_proxy

Each section is a frozen dataclass; a key the dataclass doesn't have, or a missing one, fails at load, so a typo in
tools.yml stops the tool instead of being ignored. (No `from __future__ import annotations`: the field types must
be real objects, however this module is imported.)
"""

import dataclasses
import typing
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import yaml

TOOLS_YML = Path(__file__).resolve().with_name("tools.yml")


class ToolsConfigError(ValueError):
    """tools.yml has an unknown or missing key, or a value of the wrong type."""


@dataclass(frozen=True)
class Listing:
    title: str
    description: str
    price: float
    tags: list[str]
    artisan_name: str


@dataclass(frozen=True)
class Order:
    buyer_name: str
    quantity: int


@dataclass(frozen=True)
class Clip:
    seconds: int
    size: str
    fps: int
    tone_hz: int
    preset: str


@dataclass(frozen=True)
class SmokeTest:
    request_timeout_s: int
    upload_timeout_s: int
    transcode_timeout_s: int
    poll_every_s: int
    error_text_chars: int
    tag_prefix: str
    listing: Listing
    search: str
    order: Order
    log_events: list[str]
    clip: Clip


@dataclass(frozen=True)
class ThrottleProxy:
    kbps: float
    rtt_ms: int
    host: str
    port: int
    chunk_bytes: int
    burst_ms: int
    report_every_s: float
    top_talkers: int


@dataclass(frozen=True)
class Sample:
    seconds: int
    size: str
    fps: int
    tone_hz: int
    sample_rate: int
    preset: str
    crf: int
    audio_kbps: int
    grain: int


@dataclass(frozen=True)
class LocalHls:
    http_header_bytes: int
    sample: Sample


@dataclass(frozen=True)
class ToolsConfig:
    smoke_test: SmokeTest
    throttle_proxy: ThrottleProxy
    local_hls: LocalHls


def _value(tp: typing.Any, value: typing.Any, where: str) -> typing.Any:
    if dataclasses.is_dataclass(tp):
        return build(tp, value, where)
    origin = typing.get_origin(tp)
    if origin is list:
        (item,) = typing.get_args(tp)
        if not isinstance(value, list):
            raise ToolsConfigError(f"{where}: expected a list, got {value!r}")
        return [_value(item, v, f"{where}[{i}]") for i, v in enumerate(value)]
    if tp is float and isinstance(value, int) and not isinstance(value, bool):
        return float(value)
    if not isinstance(value, tp) or isinstance(value, bool) is not (tp is bool):
        raise ToolsConfigError(f"{where}: expected {tp.__name__}, got {value!r}")
    return value


def build(cls: type, data: typing.Any, where: str = "tools.yml") -> typing.Any:
    """`cls` from a mapping with exactly its fields (nested dataclasses and lists are checked too)."""
    if not isinstance(data, dict):
        raise ToolsConfigError(f"{where}: expected a mapping, got {data!r}")
    hints = typing.get_type_hints(cls)
    names = [f.name for f in dataclasses.fields(cls)]
    unknown, missing = sorted(set(data) - set(names)), sorted(set(names) - set(data))
    if unknown or missing:
        raise ToolsConfigError(f"{where}: unknown keys {unknown}, missing keys {missing}")
    return cls(**{n: _value(hints[n], data[n], f"{where}.{n}") for n in names})


def load_tools_config(path: Path = TOOLS_YML) -> ToolsConfig:
    return _load(path)


@lru_cache(maxsize=4)
def _load(path: Path) -> ToolsConfig:
    return build(ToolsConfig, yaml.safe_load(path.read_text()), path.name)
