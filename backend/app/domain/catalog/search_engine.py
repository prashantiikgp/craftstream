"""Keyword search over products. Pure logic over SearchRules.

Two halves that must agree:
  index_terms(...)  -> what we store with each product (`keywords`): words, their prefixes, and `tag:<tag>`
  query_terms(q)    -> what a buyer typed, cleaned the same way
A product matches when every query term is one of its index terms, so the same rule works in memory and as
Firestore `array-contains` lookups.
"""

from __future__ import annotations

import re
from collections.abc import Iterable

from app.domain.catalog.search_loader import load_search_rules
from app.schemas.catalog.search_schema import SearchRules

_WORD = re.compile(r"[^\W_]+(?:['’][^\W_]+)*", re.UNICODE)
TAG_PREFIX = "tag:"


def _rules(rules: SearchRules | None) -> SearchRules:
    return rules or load_search_rules()


def normalize_tag(tag: str) -> str:
    return " ".join(tag.lower().split())


def words(text: str, rules: SearchRules | None = None) -> list[str]:
    """Lowercase words without stopwords or too-short words, in order, without duplicates."""
    r = _rules(rules)
    stop = set(r.stopwords)
    seen: dict[str, None] = {}
    for w in _WORD.findall(text.lower()):
        w = w.replace("’", "'")
        if len(w) >= r.min_token_length and w not in stop:
            seen.setdefault(w)
    return list(seen)


def index_terms(fields: dict[str, str | list[str]], rules: SearchRules | None = None) -> list[str]:
    """Keywords to store with a product. `fields` maps field name -> text (or list of texts, e.g. tags)."""
    r = _rules(rules)
    terms: set[str] = set()
    for name in r.searchable_fields:
        value = fields.get(name) or ""
        texts = value if isinstance(value, list) else [value]
        for w in words(" ".join(texts), r):
            terms.add(w)
            if r.prefix_match:
                terms.update(w[:n] for n in range(r.min_prefix_length, len(w)))
    terms.update(f"{TAG_PREFIX}{normalize_tag(t)}" for t in _as_list(fields.get("tags")))
    return sorted(terms)


def query_terms(q: str | None, rules: SearchRules | None = None) -> list[str]:
    """What to look up for a buyer's query. Terms shorter than min_prefix_length can't be prefix-matched,
    so with prefix matching they only match whole words."""
    r = _rules(rules)
    return words(q or "", r)[: r.max_query_terms]


def tag_term(tag: str | None) -> str | None:
    return f"{TAG_PREFIX}{normalize_tag(tag)}" if tag and tag.strip() else None


def matches(keywords: Iterable[str], terms: Iterable[str]) -> bool:
    kw = set(keywords)
    return all(t in kw for t in terms)


def most_selective(terms: list[str]) -> str | None:
    """The term to give the database (one array-contains per query): a tag, else the longest word."""
    tags = [t for t in terms if t.startswith(TAG_PREFIX)]
    if tags:
        return tags[0]
    return max(terms, key=len) if terms else None


def page_size(requested: int | None, rules: SearchRules | None = None) -> int:
    r = _rules(rules)
    return min(requested or r.page_size.default, r.page_size.max)


def _as_list(value: str | list[str] | None) -> list[str]:
    if value is None:
        return []
    return value if isinstance(value, list) else [value]
