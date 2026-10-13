"""`make gen` must have been run after the last change to models/: generated code matches the YAML."""

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def _codegen():
    spec = importlib.util.spec_from_file_location("codegen", ROOT / "tools" / "codegen.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_generated_code_matches_models():
    cg = _codegen()
    models = cg.load_models()
    api = cg.load_api(models)
    expected = {
        "backend/app/generated/models.py": cg.build_python(models),
        "frontend/lib/data/generated/models.dart": cg.build_dart_models(models),
        "frontend/lib/data/generated/api_client.dart": cg.build_dart_client(api, models),
    }
    stale = [path for path, text in expected.items() if (ROOT / path).read_text() != text]
    assert not stale, f"run `make gen`: out of date: {stale}"
