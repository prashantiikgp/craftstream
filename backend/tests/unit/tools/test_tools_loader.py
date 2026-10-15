"""tools/tools.yml: it loads with no unknown or missing keys, typos fail, and the tools take their defaults from it."""

import copy
import importlib.util
import sys
from pathlib import Path

import pytest
import yaml

TOOLS = Path(__file__).resolve().parents[4] / "tools"
sys.path.insert(0, str(TOOLS))

import tools_loader as tl

RAW = yaml.safe_load(tl.TOOLS_YML.read_text())


def _tool(name: str):
    spec = importlib.util.spec_from_file_location(name, TOOLS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module  # dataclasses look their module up here
    spec.loader.exec_module(module)
    return module


def test_tools_yml_loads_with_exactly_the_known_keys():
    cfg = tl.load_tools_config()
    assert cfg.throttle_proxy.kbps < 50  # the demo throttle stays under the 50 kbps target
    assert cfg.smoke_test.listing.tags and cfg.smoke_test.order.quantity >= 1
    assert cfg.local_hls.sample.seconds > 0


@pytest.mark.parametrize("change, message", [
    (lambda d: d["throttle_proxy"].update(kpbs=45), "unknown keys ['kpbs']"),
    (lambda d: d["smoke_test"]["clip"].pop("fps"), "missing keys ['fps']"),
    (lambda d: d.update(web_bundle={}), "unknown keys ['web_bundle']"),
    (lambda d: d["throttle_proxy"].update(port="8045"), "throttle_proxy.port: expected int"),
    (lambda d: d["smoke_test"]["listing"].update(tags="woodwork"), "expected a list"),
    (lambda d: d["local_hls"].update(sample=None), "expected a mapping"),
    (lambda d: d["throttle_proxy"].update(top_talkers=True), "expected int"),
])
def test_typos_and_wrong_types_fail(change, message):
    data = copy.deepcopy(RAW)
    change(data)
    with pytest.raises(tl.ToolsConfigError) as e:
        tl.build(tl.ToolsConfig, data)
    assert message in str(e.value)


def test_ints_are_accepted_where_a_float_is_expected():
    data = copy.deepcopy(RAW)
    data["smoke_test"]["listing"]["price"] = 500
    assert tl.build(tl.ToolsConfig, data).smoke_test.listing.price == 500.0


def test_the_tools_use_their_defaults():
    cfg = tl.load_tools_config()
    tp = _tool("throttle_proxy")
    assert tp.CHUNK == cfg.throttle_proxy.chunk_bytes
    hls = _tool("local_hls")
    assert hls.HTTP_HEADER_BYTES == cfg.local_hls.http_header_bytes


def test_smoke_test_takes_its_routes_from_endpoints_yml():
    smoke = _tool("smoke_test")
    assert smoke.path("getOrder", order_id="o1").endswith("/o1")
    assert smoke.path("health").startswith("/")
    assert smoke.API_SPEC["base_path"].startswith("/")
