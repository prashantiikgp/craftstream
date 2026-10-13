"""The ladder's job config must be valid for the real Transcoder API types (no network: proto parsing only)."""

from app.domain.media.ladder_engine import build_job_config
from app.infra.gcp.transcoder import job_config_proto


def test_job_config_parses_into_the_transcoder_proto():
    config = build_job_config(input_uri="gs://u/raw/p1", max_duration_seconds=900,
                              pubsub_topic="projects/p/topics/t")
    proto = job_config_proto(config)
    assert len(proto.elementary_streams) == len(config["elementaryStreams"])
    assert [m.key for m in proto.mux_streams] == [m["key"] for m in config["muxStreams"]]
    assert proto.pubsub_destination.topic == "projects/p/topics/t"


def test_audio_channel_layout_matches_the_channel_count():
    config = build_job_config(input_uri="gs://u/raw/p1", max_duration_seconds=900, pubsub_topic="projects/p/topics/t")
    for stream in config["elementaryStreams"]:
        if "audioStream" in stream:
            audio = stream["audioStream"]
            assert len(audio["channelLayout"]) == audio["channelCount"]
