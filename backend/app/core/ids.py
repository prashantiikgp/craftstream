"""IDs and timestamps for new records."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime


def new_id() -> str:
    return uuid.uuid4().hex[:12]


def now() -> datetime:
    return datetime.now(UTC)
