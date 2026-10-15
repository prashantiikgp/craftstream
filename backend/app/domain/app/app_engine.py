"""Start-up rules: setting defaults, which settings a mode needs, and how logs are written.
Pure logic over AppRules; core/settings.py and core/logging.py apply them.
"""

from __future__ import annotations

from collections.abc import Mapping

from app.domain.app.app_loader import load_app_rules
from app.schemas.app.app_schema import AppRules, LogFormat, SettingDefaults


def _rules(rules: AppRules | None) -> AppRules:
    return rules or load_app_rules()


def setting_defaults(rules: AppRules | None = None) -> SettingDefaults:
    return _rules(rules).defaults


def required_settings(mode: str, rules: AppRules | None = None) -> list[str]:
    return list(_rules(rules).required.get(mode, []))


def missing_settings(mode: str, values: Mapping[str, object], rules: AppRules | None = None) -> list[str]:
    """The settings `mode` requires that are unset or empty in `values` (a name `values` lacks counts too)."""
    return [name for name in required_settings(mode, rules) if not values.get(name)]


def log_format(mode: str, rules: AppRules | None = None) -> LogFormat:
    return _rules(rules).logging.format[mode]


def logger_name(rules: AppRules | None = None) -> str:
    return _rules(rules).logging.logger
