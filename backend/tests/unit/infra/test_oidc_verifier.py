"""OIDC caller checks for /internal/* (token verification itself is Google's library; we test our rules)."""

import pytest

from app.infra.gcp import auth
from app.infra.gcp.auth import CallerRejected, OidcCallerVerifier


@pytest.fixture
def verifier(monkeypatch):
    from google.oauth2 import id_token

    def fake_verify(token, request, audience):
        tokens = {
            "eventarc": {"email": "events@p.iam.gserviceaccount.com", "email_verified": True, "aud": audience},
            "stranger": {"email": "someone@gmail.com", "email_verified": True, "aud": audience},
            "unverified": {"email": "events@p.iam.gserviceaccount.com", "email_verified": False, "aud": audience},
        }
        if token not in tokens:
            raise ValueError("bad signature")
        return tokens[token]

    monkeypatch.setattr(id_token, "verify_oauth2_token", fake_verify)
    return OidcCallerVerifier("https://api.test", {"events@p.iam.gserviceaccount.com"})


def test_accepts_our_service_account(verifier):
    assert verifier.verify("Bearer eventarc") == "events@p.iam.gserviceaccount.com"


@pytest.mark.parametrize("header", [None, "", "Basic abc", "Bearer forged", "Bearer stranger", "Bearer unverified"])
def test_rejects_everything_else(verifier, header):
    with pytest.raises(CallerRejected):
        verifier.verify(header)


def test_module_imports_google_lazily():
    assert "google" not in vars(auth)
