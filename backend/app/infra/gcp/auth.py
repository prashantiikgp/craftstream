"""Verify that a call to /internal/* really comes from our Eventarc trigger or Pub/Sub subscription.

Both send `Authorization: Bearer <Google-signed OIDC ID token>` minted for a service account we choose.
We check the signature, the audience (one of our service URLs, or one plus a path: Eventarc uses the full
destination URL) and that the token belongs to that service account.
"""

from __future__ import annotations


class CallerRejected(Exception):
    pass


class OidcCallerVerifier:
    def __init__(self, audiences: list[str], allowed_emails: set[str]) -> None:
        self._audiences, self._allowed = audiences, allowed_emails

    def verify(self, authorization: str | None) -> str:
        """Return the caller's email, or raise CallerRejected."""
        if not authorization or not authorization.startswith("Bearer "):
            raise CallerRejected("missing bearer token")
        from google.auth.transport import requests as google_requests  # lazy: local mode needs no GCP libs
        from google.oauth2 import id_token

        try:
            # audience=None: Google checks signature, expiry and issuer; we check the audience below.
            claims = id_token.verify_oauth2_token(authorization.removeprefix("Bearer "), google_requests.Request(),
                                                  audience=None)
        except ValueError as e:
            raise CallerRejected(f"invalid token: {e}") from e
        aud = claims.get("aud", "")
        if not any(aud == base or aud.startswith(base.rstrip("/") + "/") for base in self._audiences):
            raise CallerRejected(f"token is for {aud or '?'}, not this service")
        email = claims.get("email", "")
        if not claims.get("email_verified") or email not in self._allowed:
            raise CallerRejected(f"caller {email or '?'} is not allowed")
        return email

