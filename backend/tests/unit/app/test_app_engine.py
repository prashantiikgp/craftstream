"""Start-up rules (app/app.yml): defaults, the settings each mode requires, the log format per mode."""

import pytest
from pydantic import ValidationError

from app.core.settings import Settings
from app.domain.app import app_engine as ae
from app.domain.app.app_loader import load_app_rules
from app.schemas.app.app_schema import AppRules


def _rules(**changes) -> AppRules:
    data = load_app_rules().model_dump()
    data.update(changes)
    return AppRules.model_validate(data)


def test_local_needs_nothing_and_gcp_needs_its_resources():
    assert ae.required_settings("local") == []
    assert {"gcp_project", "upload_bucket", "media_bucket", "transcode_topic"} <= set(ae.required_settings("gcp"))


def test_missing_settings_are_the_empty_or_absent_ones():
    rules = _rules(required={"gcp": ["a", "b", "c"]})
    assert ae.missing_settings("gcp", {"a": "x", "b": ""}, rules) == ["b", "c"]
    assert ae.missing_settings("local", {}, rules) == []


def test_every_required_name_is_a_setting():
    fields = set(Settings.model_fields)
    for mode, names in load_app_rules().required.items():
        assert set(names) <= fields, f"required.{mode} names unknown settings: {set(names) - fields}"


def test_every_default_is_a_setting_and_is_used():
    defaults = ae.setting_defaults().model_dump()
    assert set(defaults) <= set(Settings.model_fields)
    s = Settings(_env_file=None)
    assert {k: getattr(s, k) for k in defaults} == defaults


def test_log_format_per_mode():
    assert ae.log_format("gcp") == "json"
    assert ae.log_format("local") == "plain"
    assert ae.logger_name()


def test_rules_reject_typos_and_gaps():
    data = load_app_rules().model_dump()
    with pytest.raises(ValidationError):
        AppRules.model_validate({**data, "defualts": {}})
    with pytest.raises(ValidationError):
        AppRules.model_validate({**data, "logging": {"logger": "app", "format": {"gcp": "json"}}})
    with pytest.raises(ValidationError):
        AppRules.model_validate({**data, "required": {"staging": []}})
