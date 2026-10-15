"""The YAML -> schema -> loader -> engine convention, checked for every rule file.

For config/<domain>/<xyz>.yml there must be:
    app/schemas/<domain>/<xyz>_schema.py
    app/domain/<domain>/<xyz>_loader.py   (exactly one load_* function, returning a model from that schema)
    app/domain/<domain>/<xyz>_engine.py
    tests/unit/<domain>/test_<xyz>_engine.py   (every engine, wherever it sits under app/domain/)
and the other way round: no schema, loader or engine without its YAML. Every file must load, and its
editor JSON Schema (config/.schemas/) must be current.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parents[2]
CONFIG, APP = BACKEND / "config", BACKEND / "app"


def _exporter():
    spec = importlib.util.spec_from_file_location("export_rule_schemas", BACKEND.parent / "tools" / "export_rule_schemas.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


EXPORT = _exporter()
RULE_FILES = EXPORT.rule_files()
IDS = [f"{f.parent.name}/{f.name}" for f in RULE_FILES]


def test_there_are_rule_files():
    assert {f"{f.parent.name}/{f.stem}" for f in RULE_FILES} >= {
        "catalog/search", "media/ladder", "media/upload_policy", "orders/order_rules"}


def test_no_rule_files_outside_domain_folders():
    stray = [p.relative_to(CONFIG) for p in CONFIG.rglob("*.y*ml") if p.parent.parent != CONFIG]
    assert not stray, f"rule files must live at config/<domain>/<xyz>.yml: {stray}"


@pytest.mark.parametrize("rule_file", RULE_FILES, ids=IDS)
def test_each_rule_file_has_schema_loader_engine(rule_file: Path):
    domain, xyz = rule_file.parent.name, rule_file.stem
    for path in (APP / "schemas" / domain / f"{xyz}_schema.py",
                 APP / "domain" / domain / f"{xyz}_loader.py",
                 APP / "domain" / domain / f"{xyz}_engine.py"):
        assert path.exists(), f"{rule_file.relative_to(BACKEND)} needs {path.relative_to(BACKEND)}"


@pytest.mark.parametrize("rule_file", RULE_FILES, ids=IDS)
def test_loader_returns_its_schema_and_file_loads(rule_file: Path):
    model = EXPORT.root_model(rule_file)
    assert model.__module__ == f"app.schemas.{rule_file.parent.name}.{rule_file.stem}_schema"
    assert model.model_config.get("extra") == "forbid", f"{model.__name__} must reject unknown keys"
    loader = importlib.import_module(f"app.domain.{rule_file.parent.name}.{rule_file.stem}_loader")
    (load,) = [getattr(loader, n) for n in dir(loader) if n.startswith("load_") and callable(getattr(loader, n))
               and getattr(getattr(loader, n), "__module__", "") == loader.__name__]
    assert isinstance(load(), model)


@pytest.mark.parametrize("rule_file", RULE_FILES, ids=IDS)
def test_editor_schema_is_current(rule_file: Path):
    assert rule_file.read_text().splitlines()[0] == EXPORT.modeline(rule_file), "run `make gen`"
    path = EXPORT.schema_path(rule_file)
    assert path.exists() and path.read_text() == EXPORT.schema_text(rule_file), "run `make gen`"


@pytest.mark.parametrize("kind,suffix", [("schemas", "_schema"), ("domain", "_loader"), ("domain", "_engine")])
def test_nothing_without_a_rule_file(kind: str, suffix: str):
    orphans = [p.relative_to(BACKEND) for p in (APP / kind).glob(f"*/*{suffix}.py")
               if not (CONFIG / p.parent.name / f"{p.stem.removesuffix(suffix)}.yml").exists()]
    assert not orphans, f"no matching config/<domain>/<xyz>.yml for: {orphans}"


ENGINES = sorted(APP.glob("domain/**/*_engine.py"))


def test_there_are_engines():
    assert ENGINES


@pytest.mark.parametrize("engine", ENGINES, ids=[e.stem for e in ENGINES])
def test_each_engine_has_a_unit_test_file(engine: Path):
    tests = list((BACKEND / "tests" / "unit").rglob(f"test_{engine.stem}.py"))
    assert tests, f"{engine.relative_to(BACKEND)} needs tests/unit/<domain>/test_{engine.stem}.py"
