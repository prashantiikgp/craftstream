"""HTTP rules: every error code has a status, and the code lists in http.yml, models/ and the code agree."""

import re
from pathlib import Path

import pytest
import yaml

from app.core import errors
from app.domain.api import http_engine as he
from app.domain.api.http_loader import load_http_rules
from app.schemas.api.http_schema import HttpRules

BACKEND = Path(__file__).resolve().parents[3]
ERROR_RESPONSE_YML = BACKEND.parent / "models" / "error_response.yml"


def test_statuses():
    assert he.status_for("not_found") == 404
    assert he.status_for("product_not_ready", "conflict") == 409
    assert he.status_for("no_such_code", "bad_request") == 400        # falls back to the kind's code
    assert he.status_for("no_such_code") == he.status_for(he.internal_error().code) == 500


def test_codes_for_bare_statuses():
    assert he.code_for_status(405) == "method_not_allowed"
    assert he.code_for_status(409) == "conflict"                       # the first code listed with 409
    assert he.code_for_status(418) == load_http_rules().errors.unlisted_status_code


def test_error_response_model_lists_the_same_codes():
    described = yaml.safe_load(ERROR_RESPONSE_YML.read_text())["fields"]["code"]["description"]
    listed = re.findall(r"[a-z]+(?:_[a-z]+)*", described.split(":", 1)[1])
    assert sorted(listed) == sorted(load_http_rules().errors.status)


def test_every_code_the_backend_raises_is_listed():
    kinds = [errors.DomainError, *errors.DomainError.__subclasses__()]
    raised = {k.code for k in kinds}
    for f in (BACKEND / "app").rglob("*.py"):
        raised |= set(re.findall(r"""\bcode=["']([a-z_]+)["']""", f.read_text()))
    assert raised - set(load_http_rules().errors.status) == set()


def test_cors_and_gzip_come_from_the_rules():
    rules = load_http_rules()
    assert he.cors() == rules.cors and "Range" in he.cors().expose_headers
    assert he.gzip_minimum_bytes() == rules.gzip_minimum_bytes
    assert he.title() and he.version()


@pytest.mark.parametrize("change", [
    lambda d: d["errors"]["status"].update(teapot=200),                  # not an error status
    lambda d: d["errors"]["validation"].update(code="invalid"),          # code without a status
    lambda d: d.update(gzip=True),                                       # unknown key
])
def test_bad_rules_are_rejected(change):
    data = load_http_rules().model_dump()
    change(data)
    with pytest.raises(ValueError):
        HttpRules.model_validate(data)
