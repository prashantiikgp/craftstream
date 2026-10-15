"""tools/web_bundle.py: rule YAML in one hashed bundle, the app entry renamed, index.html names the bundle."""

import importlib.util
import json
from pathlib import Path

import pytest

_spec = importlib.util.spec_from_file_location(
    "web_bundle", Path(__file__).resolve().parents[4] / "tools" / "web_bundle.py"
)
wb = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(wb)


def _fake_build(tmp_path: Path) -> Path:
    web = tmp_path / "web"
    (web / "assets/assets/config/ui/screens").mkdir(parents=True)
    (web / "assets/assets/config/ui/theme.yml").write_text("colors: {}\n", "utf-8")
    (web / "assets/assets/config/ui/screens/home.yml").write_text("about: Home ₹\n", "utf-8")
    (web / "main.dart.js").write_text("console.log('app')", "utf-8")
    (web / "flutter_bootstrap.js").write_text('_flutter.buildConfig={"builds":[{"mainJsPath":"main.dart.js"}]};', "utf-8")
    (web / "index.html").write_text("<html><head><title>x</title></head><body></body></html>", "utf-8")
    return web


def test_bundles_every_rule_file_and_renames_the_entry(tmp_path):
    web = _fake_build(tmp_path)
    assert wb.main([str(web)]) == 0

    [config] = list(web.glob("config.*.json"))
    files = json.loads(config.read_text("utf-8"))
    assert files == {"assets/config/ui/theme.yml": "colors: {}\n", "assets/config/ui/screens/home.yml": "about: Home ₹\n"}

    [entry] = list(web.glob("main.*.dart.js"))
    assert not (web / "main.dart.js").exists()
    assert f'"mainJsPath":"{entry.name}"' in (web / "flutter_bootstrap.js").read_text("utf-8")
    assert f'<meta name="craftstream-config" content="{config.name}">' in (web / "index.html").read_text("utf-8")


def test_same_content_same_names(tmp_path):
    a, b = _fake_build(tmp_path / "a"), _fake_build(tmp_path / "b")
    wb.main([str(a)])
    wb.main([str(b)])
    assert sorted(p.name for p in a.iterdir()) == sorted(p.name for p in b.iterdir())


def test_running_twice_fails_clearly(tmp_path):
    web = _fake_build(tmp_path)
    wb.main([str(web)])
    with pytest.raises(SystemExit, match="already bundled"):
        wb.main([str(web)])


def test_hashed_files_from_an_earlier_build_are_removed(tmp_path):
    web = _fake_build(tmp_path)
    (web / "config.0ld0ld0ld0ld.json").write_text("{}", "utf-8")
    (web / "main.0ld0ld0ld0ld.dart.js").write_text("old", "utf-8")
    wb.main([str(web)])
    assert len(list(web.glob("config.*.json"))) == 1 and len(list(web.glob("main.*.dart.js"))) == 1
    assert not (web / "config.0ld0ld0ld0ld.json").exists()
