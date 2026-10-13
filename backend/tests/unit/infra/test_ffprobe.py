"""probe_duration against real files made with FFmpeg."""

import shutil
import subprocess

import pytest

from app.core.errors import UnreadableVideo
from app.infra.ffprobe import probe_duration

pytestmark = pytest.mark.skipif(not shutil.which("ffprobe"), reason="needs ffmpeg")


def test_measures_a_video(tmp_path):
    clip = tmp_path / "clip.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "testsrc=size=160x90:rate=10", "-t", "3",
                    "-pix_fmt", "yuv420p", str(clip)], check=True)
    assert probe_duration(str(clip)) == pytest.approx(3.0, abs=0.2)


@pytest.mark.parametrize("content", [b"", b"not a video at all" * 100])
def test_rejects_files_that_are_not_video(tmp_path, content):
    junk = tmp_path / "junk.mp4"
    junk.write_bytes(content)
    with pytest.raises(UnreadableVideo):
        probe_duration(str(junk))
