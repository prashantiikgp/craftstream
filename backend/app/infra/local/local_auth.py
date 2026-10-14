"""Local stand-in for OIDC caller checks: there is no Eventarc or Pub/Sub, so the internal routes are open."""

from __future__ import annotations


class AllowAllCallers:
    def verify(self, authorization: str | None) -> str:
        return "local"
