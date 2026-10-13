"""Upload rules: chunk size, file types and the 15-minute cap."""

import pytest
from pydantic import ValidationError

from app.domain.media.upload_policy_engine import (
    chunk_size_bytes,
    is_allowed_duration,
    is_allowed_mime_type,
    max_duration_seconds,
    transcode_cap,
)
from app.schemas.media.upload_policy_schema import UploadPolicyRules


def test_assignment_limit_is_fifteen_minutes():
    assert max_duration_seconds() == 15 * 60
    assert is_allowed_duration(900) and not is_allowed_duration(900.5) and not is_allowed_duration(0)


def test_chunk_size_is_gcs_compatible():
    assert chunk_size_bytes() % (256 * 1024) == 0


def test_mime_types():
    assert is_allowed_mime_type("video/mp4")
    assert is_allowed_mime_type("Video/MP4; codecs=avc1")
    assert not is_allowed_mime_type("image/png")


def test_chunk_size_must_be_multiple_of_256_kib():
    with pytest.raises(ValidationError):
        UploadPolicyRules(max_duration_seconds=900, allowed_mime_types=["video/mp4"], chunk_size_kib=1000)


def test_only_video_types_allowed():
    with pytest.raises(ValidationError):
        UploadPolicyRules(max_duration_seconds=900, allowed_mime_types=["application/pdf"], chunk_size_kib=256)


def test_transcode_cap_only_for_long_or_unmeasured_videos():
    assert transcode_cap(12.0) is None          # the Transcoder rejects an edit list past the input's end
    assert transcode_cap(900.0) is None
    assert transcode_cap(1085.5) == 900
    assert transcode_cap(None) == 900
