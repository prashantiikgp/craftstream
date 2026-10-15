"""The shared YAML helper: one rule file, or a rule folder that shares one schema."""

import pytest
from pydantic import BaseModel, ConfigDict

from app.core.yaml_loader import RuleFileError, load_yaml, load_yaml_folder


class Item(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str


def test_loads_and_validates_one_file(tmp_path):
    (tmp_path / "d").mkdir()
    (tmp_path / "d" / "x.yml").write_text("title: Hello\n")
    assert load_yaml("d/x.yml", Item, tmp_path) == Item(title="Hello")
    (tmp_path / "d" / "bad.yml").write_text("titel: Hello\n")
    with pytest.raises(RuleFileError, match="does not match Item"):
        load_yaml("d/bad.yml", Item, tmp_path)
    with pytest.raises(RuleFileError, match="not found"):
        load_yaml("d/none.yml", Item, tmp_path)


def test_loads_a_rule_folder_by_file_stem(tmp_path):
    folder = tmp_path / "ui" / "screens"
    folder.mkdir(parents=True)
    (folder / "home.yml").write_text("title: Home\n")
    (folder / "about.yml").write_text("title: About\n")
    (folder / "notes.txt").write_text("not a rule file\n")
    loaded = load_yaml_folder("ui/screens", Item, tmp_path)
    assert list(loaded) == ["about", "home"]
    assert loaded["home"].title == "Home"


def test_a_rule_folder_fails_on_any_bad_file_or_when_empty(tmp_path):
    folder = tmp_path / "ui" / "screens"
    folder.mkdir(parents=True)
    with pytest.raises(RuleFileError, match="no .yml files"):
        load_yaml_folder("ui/screens", Item, tmp_path)
    (folder / "home.yml").write_text("title: Home\nextra: 1\n")
    with pytest.raises(RuleFileError, match="home.yml"):
        load_yaml_folder("ui/screens", Item, tmp_path)
