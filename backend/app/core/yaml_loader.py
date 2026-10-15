"""Shared helper behind every `<xyz>_loader`: read a YAML rule file and validate it with its schema.

Each loader stays a one-liner (and owns its own cache):

    @lru_cache(maxsize=1)
    def load_xyz_rules() -> XyzRules:
        return load_yaml("<domain>/<xyz>.yml", XyzRules)

A rule folder (config/<domain>/<xyzs>/*.yml, one schema for every file in it) loads with
`load_yaml_folder("<domain>/<xyzs>", XyzRules)`, which returns {file stem: rules}.
"""

from __future__ import annotations

from pathlib import Path
from typing import TypeVar

import yaml
from pydantic import BaseModel, ValidationError

CONFIG_DIR = Path(__file__).resolve().parents[2] / "config"

T = TypeVar("T", bound=BaseModel)


class RuleFileError(RuntimeError):
    """A rule file is missing, is not valid YAML, or does not match its schema."""


def load_yaml(relative_path: str, schema: type[T], config_dir: Path = CONFIG_DIR) -> T:
    path = config_dir / relative_path
    try:
        data = yaml.safe_load(path.read_text())
    except FileNotFoundError as e:
        raise RuleFileError(f"rule file not found: {path}") from e
    except yaml.YAMLError as e:
        raise RuleFileError(f"{path} is not valid YAML: {e}") from e
    try:
        return schema.model_validate(data)
    except ValidationError as e:
        raise RuleFileError(f"{path} does not match {schema.__name__}:\n{e}") from e


def load_yaml_folder(relative_dir: str, schema: type[T], config_dir: Path = CONFIG_DIR) -> dict[str, T]:
    """A rule folder: every `*.yml` in `relative_dir`, each validated by the folder's one schema, keyed by file
    stem in name order. A missing or empty folder is an error, like a missing rule file."""
    folder = config_dir / relative_dir
    files = sorted(folder.glob("*.yml"))
    if not files:
        raise RuleFileError(f"rule folder has no .yml files: {folder}")
    return {f.stem: load_yaml(f.relative_to(config_dir).as_posix(), schema, config_dir) for f in files}
