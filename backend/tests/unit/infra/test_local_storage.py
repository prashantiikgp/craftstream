"""The local fake must behave like a GCS resumable session, or the app's uploader isn't really tested."""

from app.generated.api import ENDPOINTS
from app.infra.local.local_storage import LocalStorage


def test_upload_url_is_the_local_upload_endpoint():
    url = LocalStorage().upload_url("p1", None, "http://api.test/")
    assert url == "http://api.test" + ENDPOINTS["localUpload"].path.format(product_id="p1")
    assert ENDPOINTS["localUpload"].mode == "local"


def test_chunks_then_complete():
    s = LocalStorage()
    p = s.receive("p", "bytes 0-9/25", 10)
    assert not p.complete and p.range_header == {"Range": "bytes=0-9"}
    p = s.receive("p", "bytes 10-19/25", 10)
    assert not p.complete and p.received == 20
    assert s.receive("p", "bytes 20-24/25", 5).complete


def test_status_query_after_drop():
    s = LocalStorage()
    s.receive("p", "bytes 0-9/100", 10)
    p = s.receive("p", "bytes */100", 0)
    assert not p.complete and p.range_header == {"Range": "bytes=0-9"}


def test_gap_is_not_accepted():
    s = LocalStorage()
    s.receive("p", "bytes 0-9/100", 10)
    p = s.receive("p", "bytes 50-59/100", 10)  # skipped 10..49
    assert not p.complete and p.received == 10


def test_resend_of_received_chunk_is_harmless():
    s = LocalStorage()
    s.receive("p", "bytes 0-9/20", 10)
    assert s.receive("p", "bytes 0-9/20", 10).received == 10
    assert s.receive("p", "bytes 10-19/20", 10).complete


def test_status_query_before_any_bytes():
    p = LocalStorage().receive("p", "bytes */100", 0)
    assert not p.complete and p.range_header == {}


def test_single_put():
    assert LocalStorage().receive("p", None, 123).complete
