"""HTTP rules: the status for an error code, the code for a bare status, CORS and compression settings.
Pure logic over HttpRules; core/errors.py and main.py apply them to FastAPI.
"""

from __future__ import annotations

from app.domain.api.http_loader import load_http_rules
from app.schemas.api.http_schema import CorsRules, DefaultError, HttpRules


def _rules(rules: HttpRules | None) -> HttpRules:
    return rules or load_http_rules()


def status_for(*codes: str, rules: HttpRules | None = None) -> int:
    """The HTTP status of the first listed code (an error's own code, then its kind's default).
    No listed code is a bug: it gets the internal error's status."""
    e = _rules(rules).errors
    return next((e.status[c] for c in codes if c in e.status), e.status[e.internal.code])


def code_for_status(status: int, rules: HttpRules | None = None) -> str:
    """The code for a framework error that only has a status: the first code listed with it."""
    e = _rules(rules).errors
    return next((c for c, s in e.status.items() if s == status), e.unlisted_status_code)


def validation_error(rules: HttpRules | None = None) -> DefaultError:
    return _rules(rules).errors.validation


def internal_error(rules: HttpRules | None = None) -> DefaultError:
    return _rules(rules).errors.internal


def cors(rules: HttpRules | None = None) -> CorsRules:
    return _rules(rules).cors


def gzip_minimum_bytes(rules: HttpRules | None = None) -> int:
    return _rules(rules).gzip_minimum_bytes


def title(rules: HttpRules | None = None) -> str:
    return _rules(rules).title


def version(rules: HttpRules | None = None) -> str:
    return _rules(rules).version
