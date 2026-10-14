"""The lowest rung must fit the assignment's 50 kbps limit, and the GCP job must include every rung."""

import pytest

from app.domain.media.ladder_engine import (
    build_job_config,
    ffmpeg_args,
    h264_profile,
    lowest_rung_within_budget,
    master_playlist,
    sorted_rungs,
)
from app.domain.media.ladder_loader import load_ladder_rules
from app.schemas.media.ladder_schema import H264Profile


def test_lowest_rung_fits_budget():
    assert lowest_rung_within_budget()


def test_rungs_sorted_low_to_high():
    kbps = [r.total_kbps for r in sorted_rungs()]
    assert kbps == sorted(kbps)


def test_job_config_has_all_rungs():
    rungs = load_ladder_rules().rungs
    cfg = build_job_config()
    assert len(cfg["elementaryStreams"]) == 2 * len(rungs)
    assert len(cfg["manifests"][0]["muxStreams"]) == 2 * len(rungs)
    assert all(m["container"] == "fmp4" for m in cfg["muxStreams"])


def test_thumbnail_comes_from_the_rules():
    rules = load_ladder_rules()
    (sheet,) = build_job_config()["spriteSheets"]
    assert (sheet["spriteWidthPixels"], sheet["spriteHeightPixels"]) == (rules.thumbnail.width, rules.thumbnail.height)
    assert sheet["quality"] == rules.thumbnail.jpeg_quality < 100  # small enough for a 45 kbps catalog
    assert sheet["totalCount"] == 1


def test_budget_violation_is_detected():
    rules = load_ladder_rules()
    too_big = rules.model_copy(update={"max_lowest_rung_total_kbps": sorted_rungs(rules)[0].total_kbps - 1})
    assert not lowest_rung_within_budget(too_big)


def test_unknown_yaml_key_is_rejected():
    data = load_ladder_rules().model_dump()
    data["segment_secs"] = 4  # typo
    with pytest.raises(ValueError):
        type(load_ladder_rules()).model_validate(data)


def test_duration_cap_adds_edit_list():
    cfg = build_job_config(input_uri="gs://up/raw/abc/source", max_duration_seconds=900)
    assert cfg["inputs"] == [{"key": "input0", "uri": "gs://up/raw/abc/source"}]
    assert cfg["editList"][0]["endTimeOffset"] == "900s"
    assert "editList" not in build_job_config()


def test_uncapped_job_still_names_its_input():
    cfg = build_job_config(input_uri="gs://up/raw/abc/source", max_duration_seconds=None)
    assert cfg["inputs"] == [{"key": "input0", "uri": "gs://up/raw/abc/source"}] and "editList" not in cfg


def test_duration_cap_needs_input_uri():
    with pytest.raises(ValueError):
        build_job_config(max_duration_seconds=900)


def test_job_reports_to_pubsub_topic():
    cfg = build_job_config(pubsub_topic="projects/p/topics/transcode-done")
    assert cfg["pubsubDestination"] == {"topic": "projects/p/topics/transcode-done"}
    assert "pubsubDestination" not in build_job_config()


def test_h264_profile_follows_the_encoder_rules():
    rules = load_ladder_rules()
    by_height = {r.height: h264_profile(r) for r in rules.rungs}
    assert by_height[144] == by_height[240] == "baseline" and by_height[360] == by_height[720] == "main"
    all_main = rules.encoder.model_copy(update={"h264_profiles": [H264Profile(profile="main")]})
    assert h264_profile(sorted_rungs()[0], rules.model_copy(update={"encoder": all_main})) == "main"


def test_transcoder_settings_come_from_the_encoder_block():
    enc = load_ladder_rules().encoder.transcoder
    cfg = build_job_config(input_uri="gs://up/raw/abc/source", max_duration_seconds=900)
    lowest = cfg["elementaryStreams"][0]["videoStream"]["h264"]
    assert lowest["rateControlMode"] == enc.rate_control and lowest["profile"] == "baseline"
    assert cfg["elementaryStreams"][1]["audioStream"]["codec"] == enc.audio_codecs["he-aac"]
    assert cfg["muxStreams"][0]["key"].endswith(enc.container)
    assert cfg["editList"][0]["key"] == enc.edit_atom_key and cfg["editList"][0]["inputs"] == [enc.input_key]


def test_ffmpeg_args_for_the_lowest_rung():
    rung = sorted_rungs()[0]
    args = ffmpeg_args(rung, "in.mp4", "out", he_aac_available=True)
    ff = load_ladder_rules().encoder.ffmpeg
    assert args[args.index("-maxrate") + 1] == f"{int(rung.video_kbps * ff.maxrate_factor)}k"
    assert args[args.index("-bufsize") + 1] == f"{rung.video_kbps * 2}k"
    assert args[args.index("-c:a") + 1] == ff.he_aac.codec
    assert args[-1] == f"out/{ff.playlist}"
    assert ffmpeg_args(rung, "in.mp4", "out")[args.index("-c:a") + 1] == ff.audio_codec


def test_master_playlist_lists_the_lowest_rung_first():
    rungs = sorted_rungs()
    lines = master_playlist(rungs).splitlines()
    assert lines[:2] == ["#EXTM3U", "#EXT-X-VERSION:7"]
    assert lines[2] == f"#EXT-X-STREAM-INF:BANDWIDTH={int(rungs[0].total_kbps * 1100)},RESOLUTION=256x144"
    assert lines[3] == f"{rungs[0].name}/index.m3u8"


@pytest.mark.parametrize("change", [
    lambda e: e["h264_profiles"].pop(),                                      # no catch-all profile
    lambda e: e["transcoder"]["channel_layouts"].update({1: ["fl", "fr"]}),  # 2 names for 1 channel
    lambda e: e["transcoder"]["audio_codecs"].pop("he-aac"),                 # a rung's audio can't be encoded
    lambda e: e["ffmpeg"].update(crf=23),                                    # unknown key
])
def test_bad_encoder_rules_are_rejected(change):
    data = load_ladder_rules().model_dump()
    change(data["encoder"])
    with pytest.raises(ValueError):
        type(load_ladder_rules()).model_validate(data)
