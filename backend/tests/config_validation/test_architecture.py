"""The layer rules from backend/CLAUDE.md, enforced by reading each module's imports.

    engines       -> only their schema/loader (+ core): no FastAPI, repositories, infra or Google SDKs
    services      -> no FastAPI / Starlette (HTTP lives in routers and core/errors.py)
    routers       -> no repositories, infra or Google SDKs (they call services)
    repositories  -> no domain logic, no FastAPI
"""

from __future__ import annotations

import ast
from pathlib import Path

import pytest

APP = Path(__file__).resolve().parents[2] / "app"


def _imports(path: Path) -> set[str]:
    out: set[str] = set()
    for node in ast.walk(ast.parse(path.read_text())):
        if isinstance(node, ast.Import):
            out |= {a.name for a in node.names}
        elif isinstance(node, ast.ImportFrom) and node.module:
            out.add(node.module)
    return out


def _files(pattern: str) -> list[Path]:
    return sorted(APP.glob(pattern))


def _violations(files: list[Path], banned: tuple[str, ...]) -> list[str]:
    return [f"{f.relative_to(APP)} imports {m}" for f in files for m in sorted(_imports(f))
            if m.startswith(banned)]


RULES = {
    "engines": (_files("domain/*/*_engine.py"),
                ("fastapi", "starlette", "google", "app.db", "app.infra", "app.api")),
    "services": (_files("domain/*/*_service.py"), ("fastapi", "starlette", "app.api")),
    "routers": (_files("api/routers/*.py"), ("google", "app.db", "app.infra")),
    "repositories": (_files("db/repositories/*.py"), ("fastapi", "starlette", "app.domain", "app.api")),
    "schemas": (_files("schemas/**/*.py"), ("fastapi", "google", "app.db", "app.infra", "app.api", "app.domain")),
}


@pytest.mark.parametrize("layer", RULES)
def test_layer_imports(layer):
    files, banned = RULES[layer]
    assert files, f"no files found for {layer}"
    assert not _violations(files, banned)


def test_google_sdks_are_imported_lazily():
    """Module-level Google imports would break local mode and slow cold starts."""
    eager = []
    for f in APP.rglob("*.py"):
        tree = ast.parse(f.read_text())
        for node in tree.body:  # top level only; imports inside functions are fine
            mods = [a.name for a in node.names] if isinstance(node, ast.Import) else \
                [node.module or ""] if isinstance(node, ast.ImportFrom) else []
            eager += [f"{f.relative_to(APP)}: {m}" for m in mods if m.startswith("google")]
    assert not eager
