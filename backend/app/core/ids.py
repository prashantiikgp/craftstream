"""IDs and timestamps for new records. The id length comes from catalog/listing.yml (listing_engine)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from app.domain.catalog import listing_engine


def new_id() -> str:
    return uuid.uuid4().hex[:listing_engine.id_length()]


def now() -> datetime:
    return datetime.now(UTC)
