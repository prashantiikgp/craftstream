"""The public URLs GcsStorage hands out (no network: these never call Google)."""

from app.infra.gcp.gcs import GcsStorage


def test_hls_and_thumbnail_urls():
    s = GcsStorage("proj", "up-bucket", "media-bucket")
    assert s.hls_url("p1") == "https://storage.googleapis.com/media-bucket/hls/p1/manifest.m3u8"
    assert s.thumbnail_url("p1") == "https://storage.googleapis.com/media-bucket/hls/p1/thumb0000000000.jpeg"
