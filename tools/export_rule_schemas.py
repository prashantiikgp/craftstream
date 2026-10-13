"""Write a JSON Schema for every backend rule file, so editors validate and autocomplete the YAML.

    backend/config/<domain>/<xyz>.yml  ->  backend/config/.schemas/<domain>/<xyz>.schema.json

Each YAML's first line points at its schema (the Red Hat YAML extension reads it):
    # yaml-language-server: $schema=../.schemas/<domain>/<xyz>.schema.json

The schema comes from the Pydantic model that `<xyz>_loader.load_*()` returns. Run via `make gen`.
"""

from __future__ import annotations

import importlib
import inspect
import json
import sys
import typing
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
CONFIG = BACKEND / "config"
SCHEMA_DIR = CONFIG / ".schemas"
sys.path.insert(0, str(BACKEND))


def rule_files() -> list[Path]:
    return sorted(p for p in CONFIG.glob("*/*.yml"))


def root_model(rule_file: Path) -> type:
    """The return type of the single public `load_*` function in domain/<domain>/<xyz>_loader.py."""
    module = importlib.import_module(f"app.domain.{rule_file.parent.name}.{rule_file.stem}_loader")
    loaders = [inspect.unwrap(f) for name, f in inspect.getmembers(module, callable)  # unwrap lru_cache
               if name.startswith("load_") and inspect.unwrap(f).__module__ == module.__name__]
    if len(loaders) != 1:
        raise RuntimeError(f"{module.__name__} must define exactly one load_* function, found {len(loaders)}")
    return typing.get_type_hints(loaders[0])["return"]


def schema_path(rule_file: Path) -> Path:
    return SCHEMA_DIR / rule_file.parent.name / f"{rule_file.stem}.schema.json"


def modeline(rule_file: Path) -> str:
    rel = Path("..") / ".schemas" / rule_file.parent.name / f"{rule_file.stem}.schema.json"
    return f"# yaml-language-server: $schema={rel.as_posix()}"


def schema_text(rule_file: Path) -> str:
    schema = root_model(rule_file).model_json_schema()
    schema["$comment"] = f"GENERATED from the Pydantic schema by tools/export_rule_schemas.py for {rule_file.name}."
    return json.dumps(schema, indent=2) + "\n"


def main() -> None:
    print("Exporting rule-file schemas ...")
    for f in rule_files():
        out = schema_path(f)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(schema_text(f))
        print(f"  wrote {out.relative_to(ROOT)}")
        lines = f.read_text().splitlines(keepends=True)
        if not lines or not lines[0].startswith("# yaml-language-server:"):
            f.write_text(modeline(f) + "\n" + "".join(lines))
            print(f"  added schema line to {f.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
