"""FirestoreLogRepo builds its query with the real Firestore library (no network): filters, newest first, ties by
document id, cursor, limit. A wrong import here only failed on Cloud Run (HTTP 500 on GET /logs)."""

from types import SimpleNamespace

from app.db.repositories.log_repo import FILTERS, ORDER_BY, FirestoreLogRepo


class _Query:
    def __init__(self, calls: list) -> None:
        self.calls = calls

    def where(self, *, filter):
        self.calls.append(("where", filter.field_path, filter.op_string, filter.value))
        return self

    def order_by(self, field, direction):
        self.calls.append(("order_by", field, direction))
        return self

    def start_after(self, snapshot):
        self.calls.append(("start_after", snapshot.id))
        return self

    def limit(self, n):
        self.calls.append(("limit", n))
        return self

    def stream(self):
        return iter(())

    def document(self, doc_id):
        return SimpleNamespace(get=lambda: SimpleNamespace(exists=True, id=doc_id))


def _repo(calls: list) -> FirestoreLogRepo:
    repo = FirestoreLogRepo.__new__(FirestoreLogRepo)  # skip the real client
    repo._col = _Query(calls)
    return repo


def test_page_filters_orders_newest_first_then_by_id_and_pages():
    calls: list = []
    assert _repo(calls).page(group="upload", level=None, product_id="p1", cursor="e9", limit=31) == []
    assert ("where", FILTERS[0], "==", "upload") in calls and ("where", FILTERS[2], "==", "p1") in calls
    assert not any(c[0] == "where" and c[1] == FILTERS[1] for c in calls)
    orders = [c for c in calls if c[0] == "order_by"]
    assert [o[1] for o in orders] == [ORDER_BY, "__name__"] and {o[2] for o in orders} == {"DESCENDING"}
    assert ("start_after", "e9") in calls and calls[-1] == ("limit", 31)
