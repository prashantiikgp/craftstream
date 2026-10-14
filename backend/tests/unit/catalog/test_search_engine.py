"""Search rules: tokenising, prefixes, stopwords, tags and paging."""

from app.domain.catalog import search_engine as se
from app.domain.catalog.search_loader import load_search_rules

MUG = {"title": "Hand-thrown Clay Mug", "description": "Glazed by hand, fired twice.",
       "tags": ["pottery", "kitchen ware"], "artisan_name": "Meera"}


def test_words_drop_stopwords_short_words_and_duplicates():
    assert se.words("The mug and THE Mug, a cup for tea!") == ["mug", "cup", "tea"]


def test_index_has_words_prefixes_and_tags():
    kw = set(se.index_terms(MUG))
    assert {"clay", "mug", "pottery", "meera", "glazed"} <= kw
    assert {"pot", "pott", "potter"} <= kw          # prefixes from min_prefix_length
    assert "po" not in kw                            # too short to be a prefix
    assert {"tag:pottery", "tag:kitchen ware"} <= kw
    assert "the" not in kw and "by" not in kw


def test_prefix_query_matches():
    kw = se.index_terms(MUG)
    assert se.matches(kw, se.query_terms("pott clay"))
    assert not se.matches(kw, se.query_terms("pott glass"))


def test_query_of_only_stopwords_matches_everything():
    assert se.query_terms("the handmade") == []
    assert se.matches(se.index_terms(MUG), [])


def test_query_terms_are_capped():
    rules = load_search_rules()
    assert len(se.query_terms(" ".join(f"word{i}" for i in range(20)))) == rules.max_query_terms


def test_tag_terms():  # tags come in cleaned (listing_engine.normalize_tag)
    assert se.tag_term("kitchen ware") == "tag:kitchen ware"
    assert se.tag_term("") is None and se.tag_term(None) is None


def test_most_selective_prefers_tag_then_longest_word():
    assert se.most_selective(["mug", "tag:pottery", "glazed"]) == "tag:pottery"
    assert se.most_selective(["mug", "glazed"]) == "glazed"
    assert se.most_selective([]) is None


def test_without_prefix_match_only_whole_words_are_indexed():
    rules = load_search_rules().model_copy(update={"prefix_match": False})
    kw = se.index_terms(MUG, rules)
    assert "pottery" in kw and "pott" not in kw


def test_page_size_default_and_cap():
    rules = load_search_rules()
    assert se.page_size(None) == rules.page_size.default
    assert se.page_size(10_000) == rules.page_size.max
    assert se.page_size(3) == 3
