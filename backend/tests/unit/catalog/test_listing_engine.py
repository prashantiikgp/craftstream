"""Listing rules: ids, tag clean-up and order, Firestore names."""

import pytest

from app.core.ids import new_id
from app.domain.catalog import listing_engine as le
from app.domain.catalog.listing_loader import load_listing_rules
from app.schemas.catalog.listing_schema import ListingRules, TagRules


def _with_tags(**changes) -> ListingRules:
    rules = load_listing_rules()
    return rules.model_copy(update={"tags": rules.tags.model_copy(update=changes)})


def test_ids_have_the_configured_length():
    assert len(new_id()) == le.id_length() == load_listing_rules().id_length
    assert int(new_id(), 16) >= 0  # hex


def test_tags_are_normalised():
    assert le.normalize_tag("  Kitchen   Ware ") == "kitchen ware"
    assert le.normalize_tag("  Kitchen   Ware ", _with_tags(lowercase=False, collapse_spaces=False)) == "Kitchen   Ware"


def test_clean_tags_drops_blanks_and_duplicates_in_order():
    assert le.clean_tags(["Pottery", " ", "kitchen  ware", "POTTERY"]) == ["pottery", "kitchen ware"]


def test_tag_list_order():
    counts = {"wood": 1, "clay": 3, "brass": 1}
    assert le.tag_list(counts) == ["clay", "brass", "wood"]          # most used, ties A-Z
    assert le.tag_list(counts, _with_tags(order="alphabetical")) == ["brass", "clay", "wood"]


def test_firestore_names():
    assert le.products_collection() and le.orders_collection()
    assert le.products_collection() != le.orders_collection()
    assert le.search_candidate_limit() > 0


@pytest.mark.parametrize("update", [{"id_length": 4}, {"id_length": 40}, {"search_candidate_limit": 0},
                                    {"cursor": "offset"}])
def test_bad_rules_are_rejected(update):
    data = {**load_listing_rules().model_dump(), **update}
    with pytest.raises(ValueError):
        ListingRules.model_validate(data)


def test_unknown_tag_order_is_rejected():
    with pytest.raises(ValueError):
        TagRules(lowercase=True, collapse_spaces=True, order="random")
