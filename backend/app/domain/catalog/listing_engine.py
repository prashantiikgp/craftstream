"""Listing rules: id length, tag clean-up, tag list order and Firestore storage. Pure logic over ListingRules."""

from __future__ import annotations

from collections.abc import Iterable, Mapping

from app.domain.catalog.listing_loader import load_listing_rules
from app.schemas.catalog.listing_schema import ListingRules


def _rules(rules: ListingRules | None) -> ListingRules:
    return rules or load_listing_rules()


def id_length(rules: ListingRules | None = None) -> int:
    return _rules(rules).id_length


def normalize_tag(tag: str, rules: ListingRules | None = None) -> str:
    t = _rules(rules).tags
    tag = " ".join(tag.split()) if t.collapse_spaces else tag.strip()
    return tag.lower() if t.lowercase else tag


def clean_tags(tags: Iterable[str], rules: ListingRules | None = None) -> list[str]:
    """Normalised tags in their original order, without blanks or duplicates."""
    r = _rules(rules)
    return list(dict.fromkeys(n for n in (normalize_tag(t, r) for t in tags) if n))


def tag_list(counts: Mapping[str, int], rules: ListingRules | None = None) -> list[str]:
    """Tags in GET /tags order, from how many listed products carry each."""
    if _rules(rules).tags.order == "alphabetical":
        return sorted(counts)
    return [t for t, _ in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))]


def search_candidate_limit(rules: ListingRules | None = None) -> int:
    return _rules(rules).search_candidate_limit


def products_collection(rules: ListingRules | None = None) -> str:
    return _rules(rules).collections.products


def orders_collection(rules: ListingRules | None = None) -> str:
    return _rules(rules).collections.orders
