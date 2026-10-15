"""infra/gcp/resources.yml must agree with the backend: object names, callback paths, the Eventarc event type,
Firestore collections, the indexes the product and activity log queries need, and the log's TTL policy.
Read-only: nothing here calls GCP.
"""

from __future__ import annotations

import importlib.util
import re
from pathlib import Path

import pytest

from app.db.repositories import log_repo
from app.domain.catalog.listing_loader import load_listing_rules
from app.domain.media.storage_layout_loader import load_storage_layout_rules
from app.domain.platform.activity_log_loader import load_activity_log_rules
from app.domain.platform.events_loader import load_events_rules
from app.generated.api import ENDPOINTS
from app.generated.models import LogEntry, Product

ROOT = Path(__file__).resolve().parents[3]
GCP = ROOT / "infra" / "gcp"
PRODUCT_REPO = ROOT / "backend" / "app" / "db" / "repositories" / "product_repo.py"


def _reader():
    spec = importlib.util.spec_from_file_location("resources", GCP / "resources.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


RES = _reader()
ENV = RES.config_env(GCP / "config.env.example")
DATA = RES.load(ENV)


def test_raw_uploads_are_where_the_lifecycle_deletes_them():
    layout = load_storage_layout_rules()
    prefix = DATA["buckets"]["uploads"]["lifecycle"]["delete_prefix"]
    assert layout.raw_object.startswith(prefix)
    assert prefix not in layout.hls_prefix  # HLS output lives in the media bucket and is kept


def test_buckets_are_private_for_uploads_and_public_for_media():
    uploads, media = DATA["buckets"]["uploads"], DATA["buckets"]["media"]
    assert not uploads["public"] and media["public"]
    assert ("media", "allUsers", "roles/storage.objectViewer") in {
        (b["bucket"], b["member"], b["role"]) for b in DATA["iam"]["buckets"]}
    assert "PUT" in uploads["cors"]["methods"] and "Range" in uploads["cors"]["response_headers"]
    assert "GET" in media["cors"]["methods"]


def test_callbacks_point_at_the_internal_routes():
    ev = load_events_rules()
    assert DATA["eventarc"]["path"] == ENDPOINTS["mediaUploaded"].path
    assert DATA["eventarc"]["event_type"] in ev.upload_finalized.accepted_event_types
    assert DATA["eventarc"]["bucket"] == "uploads"
    assert DATA["pubsub"]["subscription"]["push_path"] == ENDPOINTS["mediaTranscoded"].path


def _queries() -> list[list[str]]:
    """Field order of each Firestore query in product_repo: its equality/array filters, then its order_by."""
    src = PRODUCT_REPO.read_text()
    filters = re.findall(r'FieldFilter\("(\w+)", "([^"]+)"', src)
    (order_by,) = re.findall(r'order_by\("(\w+)"', src)
    plain = [f for f, op in filters if op == "=="]
    arrays = [f for f, op in filters if op == "array_contains"]
    return [plain + [order_by], plain + arrays + [order_by]]


def _indexes(collection: str) -> list[dict]:
    return [ix for ix in DATA["firestore"]["indexes"] if ix["collection"] == collection]


def test_indexes_are_only_for_our_collections():
    ours = {load_listing_rules().collections.products, load_activity_log_rules().collection}
    assert {ix["collection"] for ix in DATA["firestore"]["indexes"]} <= ours


def test_every_product_query_has_its_index():
    indexes = [[f["path"] for f in ix["fields"]] for ix in _indexes(load_listing_rules().collections.products)]
    for query in _queries():
        assert query in indexes, f"no composite index for {query}"


def test_index_fields_exist_on_products():
    known = set(Product.model_fields) | {"keywords"}  # keywords: the search index stored with each product
    for ix in _indexes(load_listing_rules().collections.products):
        assert {f["path"] for f in ix["fields"]} <= known


def test_the_activity_log_has_one_index_per_filter_newest_first():
    """FirestoreLogRepo filters by equality on any mix of log_repo.FILTERS and orders by ORDER_BY desc; Firestore
    merges these single-filter indexes for combined filters."""
    indexes = {tuple((f["path"], f.get("order")) for f in ix["fields"])
               for ix in _indexes(load_activity_log_rules().collection)}
    assert indexes == {((f, "ascending"), (log_repo.ORDER_BY, "descending")) for f in log_repo.FILTERS}
    assert set(log_repo.FILTERS) | {log_repo.ORDER_BY} <= set(LogEntry.model_fields)


def test_the_activity_log_expires_by_ttl():
    rules = load_activity_log_rules()
    assert {"collection": rules.collection, "field": rules.expire_field} in DATA["firestore"]["ttl"]
    assert f"ttls update {rules.expire_field} --collection-group={rules.collection} --enable-ttl" in \
        "\n".join(RES.dry_run(DATA, ENV))


def test_dry_run_fills_every_value_but_the_project_number():
    commands = "\n".join(RES.dry_run(DATA, ENV))
    assert set(re.findall(r"\$\{(\w+)\}", commands)) <= {"PROJECT_NUMBER"}
    assert f"--max-instances {DATA['cloud_run']['max_instances']}" in commands
    assert all(f"gs://{b['name']}" in commands for b in DATA["buckets"].values())


@pytest.mark.parametrize("change", [
    lambda d: d["iam"]["project"].append({"member": "sa:apii", "role": "roles/viewer"}),   # typo in a member
    lambda d: d["iam"]["buckets"].append({"bucket": "raw", "member": "allUsers", "role": "x"}),
    lambda d: d.update(bukets={}),                                                        # unknown section
])
def test_typos_are_rejected(change):
    import copy

    data = copy.deepcopy(DATA)
    change(data)
    with pytest.raises(RES.ResourceError):
        RES.check(data)
