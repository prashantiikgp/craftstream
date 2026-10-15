"""A bandwidth-capped HTTP proxy for the throttled Android demo (R5: smooth playback under 50 kbps).

The Android emulator's own `-netspeed` shaper is unusable at these rates: at 45 kbps it delivered a 55 KB file in
more than 200 s (about 2 kbps), so the catalog request alone timed out. This proxy caps throughput exactly. The
emulator's `-http-proxy` flag sends every TCP connection the guest makes through it, so no app can bypass it.

One shared budget per direction covers all connections, like a real slow link: with 45 kbps, the API calls,
thumbnails, playlists and video segments all share 45 kbps down and 45 kbps up.

    python3 tools/throttle_proxy.py --kbps 45 --rtt-ms 300            # listens on 127.0.0.1:8045
    emulator.exe -avd <name> -http-proxy http://127.0.0.1:8045 ...    # WSL mirrored networking: Windows reaches it

Every few seconds it prints the measured throughput, so the recording can show the cap holds.
Defaults (cap, delay, address, chunk and burst sizes, report interval) are in tools/tools.yml.
Standard library + PyYAML (backend/.venv/bin/python, or any python3 that has PyYAML).
"""

from __future__ import annotations

import argparse
import asyncio
import contextlib
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from tools_loader import load_tools_config

CFG = load_tools_config().throttle_proxy
CHUNK = CFG.chunk_bytes  # bytes per relay step: small enough that one connection cannot hog the budget


class TokenBucket:
    """Shared byte budget: `rate` bytes per second, bursts of at most `burst` bytes."""

    def __init__(self, rate: float, burst: int, clock=time.monotonic):
        self.rate, self.burst, self._clock = rate, burst, clock
        self._tokens = float(burst)
        self._last = clock()
        self._lock = asyncio.Lock()

    def _refill(self) -> None:
        now = self._clock()
        self._tokens = min(self.burst, self._tokens + (now - self._last) * self.rate)
        self._last = now

    async def take(self, n: int) -> None:
        async with self._lock:  # first come, first served across connections
            self._refill()
            if self._tokens < n:
                await asyncio.sleep((n - self._tokens) / self.rate)
                self._refill()
            self._tokens -= n


@dataclass
class Meter:
    down: int = 0
    up: int = 0
    started: float = field(default_factory=time.monotonic)


async def _pipe(
    src: asyncio.StreamReader,
    dst: asyncio.StreamWriter,
    bucket: TokenBucket,
    meter: Meter,
    down: bool,
    conn: Meter | None = None,
):
    try:
        while chunk := await src.read(CHUNK):
            await bucket.take(len(chunk))
            dst.write(chunk)
            await dst.drain()
            for m in (meter, conn):
                if m is None:
                    continue
                if down:
                    m.down += len(chunk)
                else:
                    m.up += len(chunk)
    except (ConnectionError, asyncio.IncompleteReadError):
        pass
    finally:
        with contextlib.suppress(OSError, RuntimeError):
            dst.close()


async def _read_head(reader: asyncio.StreamReader) -> bytes:
    return await reader.readuntil(b"\r\n\r\n")


def _target(head: bytes) -> tuple[str, int, bytes | None]:
    """(host, port, bytes to send upstream first). CONNECT tunnels send nothing; absolute-form requests
    (`GET http://host/path`) are rewritten to origin form and forwarded."""
    line, _, rest = head.partition(b"\r\n")
    method, url, version = line.decode("latin-1").split(" ", 2)
    if method.upper() == "CONNECT":
        host, _, port = url.rpartition(":")
        return host.strip("[]"), int(port), None
    if not url.startswith("http://"):
        raise ValueError(f"not a proxy request: {line!r}")
    hostport, _, path = url[len("http://"):].partition("/")
    host, _, port = hostport.partition(":")
    first = f"{method} /{path} {version}\r\n".encode("latin-1") + rest
    return host, int(port or 80), first


class Proxy:
    def __init__(self, kbps: float, rtt_ms: int, verbose: bool = False):
        rate = kbps * 1000 / 8
        burst = max(CHUNK, int(rate * CFG.burst_ms / 1000))  # at most this much time's worth of data in one go
        self.down = TokenBucket(rate, burst)
        self.up = TokenBucket(rate, burst)
        self.rtt = rtt_ms / 1000
        self.meter = Meter()
        self.verbose = verbose
        self.active: dict[str, Meter] = {}  # open connections, for the top-talkers line

    async def handle(self, client_r: asyncio.StreamReader, client_w: asyncio.StreamWriter) -> None:
        try:
            head = await _read_head(client_r)
            host, port, first = _target(head)
            if self.rtt:
                await asyncio.sleep(self.rtt)  # the slow link's round trip, once per connection
            up_r, up_w = await asyncio.open_connection(host, port)
        except (OSError, ValueError, asyncio.IncompleteReadError, asyncio.LimitOverrunError) as e:
            if self.verbose:
                print(f"  refused: {e}")
            client_w.close()
            return
        if first is None:
            client_w.write(b"HTTP/1.1 200 Connection established\r\n\r\n")
            await client_w.drain()
        else:
            await self.up.take(len(first))
            up_w.write(first)
            await up_w.drain()
            self.meter.up += len(first)
        if self.verbose:
            print(f"  open {host}:{port}", flush=True)
        conn = Meter()
        opened = time.monotonic()
        key = f"{host}:{port}#{id(conn) % 10000}"
        self.active[key] = conn
        try:
            await asyncio.gather(
                _pipe(up_r, client_w, self.down, self.meter, down=True, conn=conn),
                _pipe(client_r, up_w, self.up, self.meter, down=False, conn=conn),
            )
        finally:
            self.active.pop(key, None)
        if self.verbose:
            secs = time.monotonic() - opened
            print(f"  close {host}:{port} after {secs:.0f}s: down {conn.down / 1000:.1f} KB, up {conn.up / 1000:.1f} KB",
                  flush=True)

    async def report(self, every: float = CFG.report_every_s) -> None:
        last = (self.meter.down, self.meter.up, time.monotonic())
        while True:
            await asyncio.sleep(every)
            d, u, t = self.meter.down, self.meter.up, time.monotonic()
            secs = t - last[2]
            print(
                f"[{time.strftime('%H:%M:%S')}] last {secs:.0f}s: down {(d - last[0]) * 8 / secs / 1000:5.1f} kbps, "
                f"up {(u - last[1]) * 8 / secs / 1000:5.1f} kbps | total down {d / 1000:.0f} KB",
                flush=True,
            )
            last = (d, u, t)
            if self.verbose and self.active:
                prev = getattr(self, "_seen", {})
                rates = sorted(((m.down - prev.get(k, 0), k) for k, m in self.active.items()),
                               reverse=True)[:CFG.top_talkers]
                self._seen = {k: m.down for k, m in self.active.items()}
                print("    top: " + ", ".join(f"{k.split('#')[0]} {b / 1000:.0f} KB" for b, k in rates if b > 0), flush=True)


async def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--kbps", type=float, default=CFG.kbps,
                    help="cap per direction, kilobits per second (default %(default)g)")
    ap.add_argument("--rtt-ms", type=int, default=CFG.rtt_ms, help="extra delay per new connection (default %(default)s)")
    ap.add_argument("--host", default=CFG.host, help="(default %(default)s)")
    ap.add_argument("--port", type=int, default=CFG.port, help="(default %(default)s)")
    ap.add_argument("-v", "--verbose", action="store_true", help="log each connection")
    a = ap.parse_args()
    proxy = Proxy(a.kbps, a.rtt_ms, a.verbose)
    server = await asyncio.start_server(proxy.handle, a.host, a.port)
    print(f"throttle proxy on {a.host}:{a.port}: {a.kbps:g} kbps each way, +{a.rtt_ms} ms per connection", flush=True)
    async with server:
        await asyncio.gather(server.serve_forever(), proxy.report())


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
