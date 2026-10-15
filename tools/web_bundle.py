"""After `flutter build web`: give the files that change with every build content-hashed names, so browsers can keep
them for good and a deploy still shows at once.

Firebase Hosting answers conditional requests (If-None-Match / If-Modified-Since) with a full 200, never 304, so
`no-cache` meant downloading the 700 KB app again on every visit: about two minutes at 45 kbps.

1. Every rule YAML under assets/config/ goes into one `config.<hash>.json` ({asset key: text}): one request
   instead of one per file. The app reads it through lib/core/config_bundle.dart.
2. `main.dart.js` becomes `main.<hash>.dart.js`; flutter_bootstrap.js is pointed at it.
3. index.html gets `<meta name="craftstream-config" content="config.<hash>.json">` so the app finds the bundle.
4. Hashed files from earlier builds are removed (`flutter build web` leaves them in place, so they would ship).

index.html and flutter_bootstrap.js stay `no-cache` (frontend/firebase.json); they are small and name the rest.

    python3 tools/web_bundle.py frontend/build/web        # `make web-build` runs it

Standard library only.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

CONFIG_DIR = "assets/assets/config"  # where flutter build web puts assets/config/
ASSET_ROOT = "assets"  # asset keys are relative to this (assets/config/ui/theme.yml)
ENTRY = "main.dart.js"
BOOTSTRAP = "flutter_bootstrap.js"
META_NAME = "craftstream-config"  # lib/core/config_bundle_web.dart looks for this <meta>
HASH_LENGTH = 12


def _short_hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:HASH_LENGTH]


def remove_stale(web: Path) -> list[str]:
    """Deletes hashed files an earlier run left in [web]; returns their names."""
    stale = sorted([*web.glob("config.*.json"), *web.glob("main.*.dart.js")])
    for p in stale:
        p.unlink()
    return [p.name for p in stale]


def bundle_config(web: Path) -> str:
    """Writes config.<hash>.json from every rule YAML and returns its file name."""
    root = web / ASSET_ROOT
    files = {p.relative_to(root).as_posix(): p.read_text("utf-8") for p in sorted((web / CONFIG_DIR).rglob("*.yml"))}
    if not files:
        raise SystemExit(f"no rule YAML under {web / CONFIG_DIR}: run flutter build web first")
    data = json.dumps(files, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")
    name = f"config.{_short_hash(data)}.json"
    (web / name).write_bytes(data)
    return name


def hash_entry(web: Path) -> str:
    """Renames main.dart.js to main.<hash>.dart.js and points flutter_bootstrap.js at it."""
    entry = web / ENTRY
    if not entry.exists():
        raise SystemExit(f"{entry} is missing: already bundled? Run flutter build web again")
    name = f"main.{_short_hash(entry.read_bytes())}.dart.js"
    bootstrap = web / BOOTSTRAP
    text = bootstrap.read_text("utf-8")
    old = f'"mainJsPath":"{ENTRY}"'
    if old not in text:
        raise SystemExit(f"{BOOTSTRAP} does not contain {old}: the Flutter loader changed, update this tool")
    bootstrap.write_text(text.replace(old, f'"mainJsPath":"{name}"'), "utf-8")
    entry.rename(web / name)
    return name


def name_bundle_in_index(web: Path, config_name: str) -> None:
    index = web / "index.html"
    text = index.read_text("utf-8")
    tag = f'<meta name="{META_NAME}" content="{config_name}">'
    if f'name="{META_NAME}"' in text:
        raise SystemExit(f"{index} already names a bundle: run flutter build web again")
    index.write_text(text.replace("</head>", f"  {tag}\n</head>", 1), "utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("web", type=Path, help="the flutter build web output (frontend/build/web)")
    web = parser.parse_args(argv).web
    if not (web / ENTRY).exists():
        raise SystemExit(f"{web / ENTRY} is missing: already bundled? Run flutter build web again")
    removed = remove_stale(web)
    config_name = bundle_config(web)
    entry_name = hash_entry(web)
    name_bundle_in_index(web, config_name)
    print(f"web_bundle: {config_name}, {entry_name}" + (f" (removed {', '.join(removed)})" if removed else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
