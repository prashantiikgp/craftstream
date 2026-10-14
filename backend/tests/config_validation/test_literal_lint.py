"""No policy literals in Python: status strings, storage paths, collection names and tunable numbers belong in
config/*.yml. Files still being migrated are listed in literal_baseline.yml with their current counts; the baseline
may only shrink (a new literal fails, and so does a count below the baseline: lower it then).

    UPDATE_LITERAL_BASELINE=1 .venv/bin/pytest tests/config_validation/test_literal_lint.py   # rewrite the baseline
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import yaml

APP = Path(__file__).resolve().parents[2] / "app"
BASELINE = Path(__file__).with_name("literal_baseline.yml")

# Schemas describe the YAML, loaders read it, generated code comes from models/: none of them hold policy.
EXEMPT = ("schemas/", "generated/", "core/yaml_loader.py")

KINDS = {
    "status": re.compile(r"""["'](awaiting_upload|processing|ready|failed|placed|SUCCEEDED|FAILED|RUNNING)["']"""),
    "path": re.compile(r"""["'][^"'\n]*(/api/|/internal/|raw/|hls/|\.m3u8|\.jpe?g|gs://|storage\.googleapis\.com)"""),
    "collection": re.compile(r"""["'](products|orders)["']"""),
    "tunable": re.compile(r"\b\w*(timeout|max_age|minimum_size|limit|retries|ttl)\w*\s*[=:]\s*\d", re.IGNORECASE),
}


def count_literals() -> dict[str, dict[str, int]]:
    out: dict[str, dict[str, int]] = {}
    for path in sorted(APP.rglob("*.py")):
        rel = path.relative_to(APP).as_posix()
        if rel.startswith(EXEMPT) or rel.endswith("_loader.py"):
            continue
        counts: dict[str, int] = {}
        for line in path.read_text().splitlines():
            if line.lstrip().startswith("#"):
                continue
            for kind, rx in KINDS.items():
                n = len(rx.findall(line))
                if n:
                    counts[kind] = counts.get(kind, 0) + n
        if counts:
            out[f"app/{rel}"] = counts
    return out


def _write_baseline(actual: dict[str, dict[str, int]]) -> None:
    lines = [
        "# Policy literals still in Python, per file and kind (see test_literal_lint.py).",
        "# This list may only shrink. Move the value to config/*.yml, then lower or delete the entry.",
    ]
    lines += [f"{f}: {{{', '.join(f'{k}: {v}' for k, v in c.items())}}}" for f, c in actual.items()]
    BASELINE.write_text("\n".join(lines) + "\n")


def test_no_new_policy_literals_and_the_baseline_only_shrinks():
    actual = count_literals()
    if os.environ.get("UPDATE_LITERAL_BASELINE") == "1":
        _write_baseline(actual)
    baseline = yaml.safe_load(BASELINE.read_text()) or {}
    problems = []
    for f in sorted(set(actual) | set(baseline)):
        now, allowed = actual.get(f, {}), baseline.get(f, {})
        for kind in sorted(set(now) | set(allowed)):
            n, a = now.get(kind, 0), allowed.get(kind, 0)
            if n > a:
                problems.append(f"{f}: {n} {kind} literal(s), baseline allows {a}. Put the value in config/.")
            elif n < a:
                problems.append(f"{f}: {kind} is down to {n}. Lower the baseline from {a}.")
    assert not problems, "\n".join(problems)
