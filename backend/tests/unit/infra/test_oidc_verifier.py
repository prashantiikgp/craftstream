"""OIDC caller checks for /internal/* (token verification itself is Google's library; we test our rules)."""

import pytest

from app.infra.gcp import auth
from app.infra.gcp.auth import CallerRejected, OidcCallerVerifier


@pytest.fixture
def verifier(monkeypatch):
    from google.oauth2 import id_token

    def fake_verify(token, request, audience):
        tokens = {
            "eventarc": {"email": "events@p.iam.gserviceaccount.com", "email_verified": True,
                         "aud": "https://hash.test/internal/media/uploaded"},
            "pubsub": {"email": "events@p.iam.gserviceaccount.com", "email_verified": True, "aud": "https://api.test"},
            "elsewhere": {"email": "events@p.iam.gserviceaccount.com", "email_verified": True, "aud": "https://other"},
            "lookalike": {"email": "events@p.iam.gserviceaccount.com", "email_verified": True,
                          "aud": "https://api.test.evil.example/internal"},
            "stranger": {"email": "someone@gmail.com", "email_verified": True, "aud": "https://api.test"},
            "unverified": {"email": "events@p.iam.gserviceaccount.com", "email_verified": False, "aud": "https://api.test"},
        }
        if token not in tokens:
            raise ValueError("bad signature")
        assert audience is None   # the verifier checks the audience itself
        return tokens[token]

    monkeypatch.setattr(id_token, "verify_oauth2_token", fake_verify)
    return OidcCallerVerifier(["https://api.test", "https://hash.test"], {"events@p.iam.gserviceaccount.com"})


@pytest.mark.parametrize("token", ["eventarc", "pubsub"])
def test_accepts_our_service_account_for_either_url(verifier, token):
    assert verifier.verify(f"Bearer {token}") == "events@p.iam.gserviceaccount.com"


@pytest.mark.parametrize("header", [None, "", "Basic abc", "Bearer forged", "Bearer stranger", "Bearer unverified",
                                    "Bearer elsewhere", "Bearer lookalike"])
def test_rejects_everything_else(verifier, header):
    with pytest.raises(CallerRejected):
        verifier.verify(header)


def test_module_imports_google_lazily():
    assert "google" not in vars(auth)
