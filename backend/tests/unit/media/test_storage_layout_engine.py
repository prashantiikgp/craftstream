"""Object names and URLs come from storage_layout.yml, and the raw-object pattern finds exactly our uploads."""

import pytest

from app.domain.media import storage_layout_engine as sl
from app.domain.media.storage_layout_loader import load_storage_layout_rules
from app.schemas.media.storage_layout_schema import StorageLayoutRules


def test_raw_object_round_trips_to_the_product_id():
    assert sl.product_id_from_object(sl.raw_object("abc_123-x")) == "abc_123-x"


@pytest.mark.parametrize("name", ["", "something/else.mp4", sl.raw_object("a") + ".bak", sl.hls_prefix("a"),
                                  "x" + sl.raw_object("a"), sl.raw_object("a/b")])
def test_other_objects_are_not_ours(name):
    assert sl.product_id_from_object(name) is None


def test_hls_objects_sit_under_the_product_prefix():
    prefix = sl.hls_prefix("p1")
    assert prefix.endswith("/") and "p1" in prefix
    assert sl.manifest_object("p1") == prefix + sl.manifest_name()
    assert sl.thumbnail_object("p1").startswith(prefix + sl.thumbnail_prefix())


def test_urls_use_the_templates():
    rules = load_storage_layout_rules()
    assert sl.object_url("b", "o") == rules.object_url.format(bucket="b", object="o")
    assert sl.gcs_uri("b", "o").endswith("b/o")
    assert "max-age" in sl.hls_cache_control()


def test_local_upload_path_names_the_product():
    assert sl.local_upload_path("p1").startswith("/") and sl.local_upload_path("p1").endswith("p1")
    assert sl.local_upload_route().startswith("/")


def test_custom_rules_are_used():
    rules = load_storage_layout_rules().model_copy(update={"manifest": "master.m3u8"})
    assert sl.manifest_object("p", rules).endswith("/master.m3u8")


@pytest.mark.parametrize("update", [
    {"raw_object_pattern": "^uploads/(?P<product_id>[a-z]+)$"},   # doesn't match raw_object
    {"raw_object_pattern": "^raw/([^/]+)/source$"},               # no named group
    {"raw_object": "raw/source"},                                  # no {product_id}
    {"hls_prefix": "hls/{product_id}"},                            # not a folder
    {"object_url": "https://example.test/{object}"},               # no {bucket}
    {"bucket_name": "x"},                                          # unknown key
])
def test_bad_rules_are_rejected(update):
    data = {**load_storage_layout_rules().model_dump(), **update}
    with pytest.raises(ValueError):
        StorageLayoutRules.model_validate(data)
