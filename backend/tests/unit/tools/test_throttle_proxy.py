"""tools/throttle_proxy.py: the cap holds and both proxy request forms reach the target."""

import asyncio
import importlib.util
import sys
import time
from pathlib import Path

import pytest

_spec = importlib.util.spec_from_file_location(
    "throttle_proxy", Path(__file__).resolve().parents[4] / "tools" / "throttle_proxy.py"
)
tp = importlib.util.module_from_spec(_spec)
sys.modules["throttle_proxy"] = tp  # dataclasses look their module up here
_spec.loader.exec_module(tp)


def test_target_parses_connect_and_absolute_form():
    assert tp._target(b"CONNECT api.example:443 HTTP/1.1\r\nHost: api.example:443\r\n\r\n") == ("api.example", 443, None)
    host, port, first = tp._target(b"GET http://cdn.example:8080/a/b.ts?x=1 HTTP/1.1\r\nHost: cdn.example\r\n\r\n")
    assert (host, port) == ("cdn.example", 8080)
    assert first == b"GET /a/b.ts?x=1 HTTP/1.1\r\nHost: cdn.example\r\n\r\n"
    with pytest.raises(ValueError):
        tp._target(b"GET /relative HTTP/1.1\r\n\r\n")


def test_bucket_holds_the_rate():
    async def run():
        bucket = tp.TokenBucket(rate=10_000, burst=512)  # 80 kbps
        start = time.monotonic()
        for _ in range(10):
            await bucket.take(512)
        return time.monotonic() - start

    elapsed = asyncio.run(run())
    # 5120 bytes, the first 512 free: (5120 - 512) / 10000 = 0.46 s
    assert 0.40 <= elapsed <= 0.8


def test_relays_connect_tunnel_at_the_cap():
    payload = b"x" * 4000

    async def run():
        async def origin(r, w):
            await r.read(5)
            w.write(payload)
            await w.drain()
            w.close()

        origin_srv = await asyncio.start_server(origin, "127.0.0.1", 0)
        oport = origin_srv.sockets[0].getsockname()[1]
        proxy = tp.Proxy(kbps=80, rtt_ms=0)  # 10 KB/s
        proxy_srv = await asyncio.start_server(proxy.handle, "127.0.0.1", 0)
        pport = proxy_srv.sockets[0].getsockname()[1]

        r, w = await asyncio.open_connection("127.0.0.1", pport)
        w.write(f"CONNECT 127.0.0.1:{oport} HTTP/1.1\r\n\r\n".encode())
        await w.drain()
        assert (await r.readuntil(b"\r\n\r\n")).startswith(b"HTTP/1.1 200")
        start = time.monotonic()
        w.write(b"hello")
        await w.drain()
        got = await r.read(-1)
        elapsed = time.monotonic() - start
        w.close()
        origin_srv.close()
        proxy_srv.close()
        return got, elapsed, proxy.meter

    got, elapsed, meter = asyncio.run(run())
    assert got == payload
    assert meter.down == len(payload) and meter.up == 5
    # 4000 bytes at 10 KB/s with a 1 KB burst: about 0.3 s, never instant
    assert elapsed >= 0.25
