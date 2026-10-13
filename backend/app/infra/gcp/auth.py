"""Verify that a call to /internal/* really comes from our Eventarc trigger or Pub/Sub subscription.

Both send `Authorization: Bearer <Google-signed OIDC ID token>` minted for a service account we choose.
We check the signature, the audience (our service URL) and that the token belongs to that service account.
"""

from __future__ import annotations


class CallerRejected(Exception):
    pass


class OidcCallerVerifier:
    def __init__(self, audience: str, allowed_emails: set[str]) -> None:
        self._audience, self._allowed = audience, allowed_emails

    def verify(self, authorization: str | None) -> str:
        """Return the caller's email, or raise CallerRejected."""
        if not authorization or not authorization.startswith("Bearer "):
            raise CallerRejected("missing bearer token")
        from google.auth.transport import requests as google_requests  # lazy: local mode needs no GCP libs
        from google.oauth2 import id_token

        try:
            claims = id_token.verify_oauth2_token(authorization.removeprefix("Bearer "), google_requests.Request(),
                                                  audience=self._audience)
        except ValueError as e:
            raise CallerRejected(f"invalid token: {e}") from e
        email = claims.get("email", "")
        if not claims.get("email_verified") or email not in self._allowed:
            raise CallerRejected(f"caller {email or '?'} is not allowed")
        return email

