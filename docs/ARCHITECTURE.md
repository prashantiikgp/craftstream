# CraftStream: Architecture

How the system fits together and why. Requirements live in [INTENT.md](INTENT.md); the build plan in [PLAN.md](PLAN.md).

## 1. The big picture

```
                         ┌───────────────────────── Google Cloud (asia-south1) ─────────────────────────┐
 Flutter app             │                                                                              │
 (Android phone/tablet,  │   Cloud Run: craftstream-api (FastAPI)          Firestore                    │
  Chrome)                │   ┌────────────────────────────┐               ┌──────────────┐              │
   │  JSON (small) ──────┼──►│ /api/v1/products, /orders,  │◄─────────────►│ products     │              │
   │                     │   │ /tags, /upload-policy       │               │ orders       │              │
   │                     │   │ /internal/media/* (OIDC)    │               └──────────────┘              │
   │                     │   └──────▲──────────────▲───────┘                                             │
   │  video bytes,       │          │ Eventarc     │ Pub/Sub push                                        │
   │  resumable chunks   │          │ (finalized)  │ (job done)                                          │
   └─────────────────────┼──►  GCS uploads bucket ─┴──► Transcoder API ──► GCS media bucket (public)     │
                         │      raw/<id>/source          HLS fMP4 ladder     hls/<id>/manifest.m3u8      │
   ◄── HLS segments ─────┼───────────────────────────────────────────────── (144p @ ~40 kbps → 720p)    │
                         └──────────────────────────────────────────────────────────────────────────────┘
```

Three rules shape everything:

1. **Video bytes never pass through the API.** The app uploads straight to Cloud Storage with a resumable session (any size, survives drops). Cloud Run's 32 MiB request limit would otherwise cap uploads, and streaming through the API would add cost and latency.
2. **The player starts on the lowest rung.** A 144p/12 fps rung of ~40 kbps exists *and* is listed first, and the player is configured to start there instead of guessing a high bandwidth.
3. **Everything small on the wire.** Search returns summaries (no description), thumbnails are single small JPEGs, and nothing autoplays in lists.

## 2. Request flows

**Artisan uploads**
1. `POST /api/v1/products` → listing saved with `video_status=awaiting_upload`; response is an `UploadTicket` (resumable URL + chunk size from `upload_policy.yml`).
2. The app checks duration and type against `GET /upload-policy`, then `PUT`s chunks with `Content-Range` straight to GCS. After a drop it asks `bytes */<total>` and resumes from the returned `Range`.
3. GCS finalizes `raw/<id>/source` → **Eventarc** → `POST /internal/media/uploaded` → `media_service` submits a Transcoder job built by `ladder_engine` (capped at 15:00 with an `editList`) → `processing`.
4. Transcoder finishes → **Pub/Sub** push → `POST /internal/media/transcoded` → `ready` + `hls_url` + `thumbnail_url` (or `failed`).

The app polls `GET /products/{id}` until `ready`. Eventarc (not the app) triggers transcoding, so closing the app after the upload is fine.

**Buyer searches, watches, orders**
1. `GET /products?q=&tag=&cursor=&limit=` → `ProductPage` of `ProductSummary`. Firestore narrows by one `keywords` term (`array-contains`); `search_engine` checks the rest.
2. `GET /products/{id}` → full product with `hls_url`; the player loads `manifest.m3u8` from the public media bucket.
3. `POST /orders` → `order_rules_engine` checks the video is ready and computes the total (Decimal rounding) → `Order(status=placed)`. The flow ends here.

## 3. One contract for both sides

```
models/*.yml + models/endpoints.yml ──make gen──┬──► backend/app/generated/models.py        (Pydantic)
                                                ├──► frontend/lib/data/generated/models.dart (Dart)
                                                ├──► frontend/lib/data/generated/api_client.dart
                                                └──► models/build/schema.json                (JSON Schema)
```

A field not in `models/` does not exist. Tests fail if generated code is stale or if the FastAPI routes (method, path, status) differ from `endpoints.yml`.

## 4. Backend layers

```
api/routers/*        HTTP only: parse, call one service, return a generated model
      │
domain/<d>/<d>_service.py      catalog · media · orders: orchestration
      │            │                     │
domain/<d>/<xyz>_engine.py   db/repositories/        infra/gcp/  (GcsStorage, GcpTranscoder)
 (pure rules)       (Protocol + InMemory          infra/local/ (LocalStorage, LocalTranscoder)
      │              + Firestore)
domain/<d>/<xyz>_loader.py ── schemas/<d>/<xyz>_schema.py ── config/<d>/<xyz>.yml
```

- **Rule files** (`config/`): `catalog/search.yml`, `media/ladder.yml`, `media/upload_policy.yml`, `orders/order_rules.yml`. Each has exactly one schema (rejects unknown keys), one cached loader and one pure engine. A convention test enforces it; `make gen` exports a JSON Schema per file for editor validation.
- **Wiring:** `api/deps.py::build_container` is the only place that reads `CRAFTSTREAM_MODE` and picks GCP or local parts. Services talk to `Storage` / `Transcoder` ports.
- **Local mode** runs the whole flow on a laptop: in-memory repos, a fake GCS resumable target at `/local-upload/{id}` (same protocol as GCS), and a transcoder that finishes instantly with a public sample stream.
- **Guards:** an architecture test reads imports (engines never touch HTTP/DB/GCP; routers never touch repos/infra; Google SDKs only imported lazily).

## 5. The bitrate ladder

From `backend/config/media/ladder.yml`; HLS with **fMP4** segments of 6 s, one keyframe per segment.

| Rung | Size | fps | Video | Audio | Total |
|---|---|---|---|---|---|
| ultra_low | 256×144 | 12 | 28 kbps H.264 baseline | 12 kbps HE-AAC mono 22 kHz | **40 kbps** |
| low | 426×240 | 15 | 120 kbps | 32 kbps AAC-LC | 152 kbps |
| medium | 640×360 | 24 | 400 kbps | 64 kbps | 464 kbps |
| high | 1280×720 | 30 | 1500 kbps | 96 kbps | 1596 kbps |

Why these choices:
- **fMP4, not MPEG-TS.** At these bitrates TS packet overhead alone added ~14 kbps (56.7 vs 42.0 kbps measured on the scaffold), enough to break the budget.
- **12 fps at 144p.** Process videos are slow hand work; frame rate is the cheapest thing to give up. Bits go to legibility.
- **HE-AAC mono at 12 kbps.** Narration stays intelligible; HE-AAC is designed for this range.
- **~10 kbps headroom** under 50 for playlists, init segment and HTTP headers.

## 6. Measured: does the lowest rung fit 50 kbps?

Measured 2026-10-13 with `tools/local_hls.py`, which encodes with the **same settings `ladder_engine` gives the
Transcoder** (FFmpeg 6.1, libx264 `veryslow`, fMP4 HLS). "On the wire" = master playlist + rung playlist + init
segment + all media segments + ~400 bytes of HTTP headers per request.

**60 s, 1080p30 source, moving test pattern (clean)**

| Rung | Payload kbps | On the wire kbps | Heaviest 6 s segment |
|---|---|---|---|
| **ultra_low** (144p) | 42.0 | **42.7** | 42.8 kbps |
| low (240p) | 154.2 | 154.9 | 157.9 kbps |
| medium (360p) | 466.3 | 467.0 | 483.3 kbps |
| high (720p) | 1572.8 | 1573.5 | 1589.4 kbps |

**Same source with heavy film grain (worst case: far harder to compress than real workshop footage)**

| Rung | Payload kbps | On the wire kbps | Heaviest 6 s segment |
|---|---|---|---|
| **ultra_low** (144p) | 42.1 | **42.8** | 42.9 kbps |
| low (240p) | 154.3 | 155.0 | 158.1 kbps |

**Result: the lowest rung is 42.8 kbps on the wire, inside the 50 kbps budget, and no single segment goes above
43 kbps.** Harder content costs picture quality, not size: the encoder's rate control (`maxrate` 1.2x, `bufsize` 2x)
holds the bitrate. `make test` re-checks this on every run (`tests/integration/test_bitrate_budget.py`, a grainy clip).

What this means at a 45 kbps throttle: each 6 s segment (~32 KB) downloads in about 5.7 s, so the buffer grows
slowly (about 1.05x real time). It plays, but the margin is thin once TCP/TLS overhead and request latency are
counted. Levers if real-device tests stall, all in `ladder.yml`: video 28 → 24 kbps (total ~36), or 10 fps.

Caveats:
- Local FFmpeg has no `libfdk_aac`, so the 12 kbps audio is AAC-LC locally and HE-AAC on GCP. Same size, better
  sound on GCP.
- GCP packages audio and video as **separate** fMP4 renditions, so a player makes two requests per 6 s instead of
  one: about +0.5 kbps of headers. Still ~43 kbps.
- Re-measure on the real Transcoder output in B4 (`gsutil du` on `hls/<id>/` vs. duration).

## 7. Key decisions

| Decision | Why | Alternative rejected |
|---|---|---|
| Flutter, one codebase | Android phone + tablet + Chrome from one code base, real native APK | React Native + separate web app |
| Direct-to-GCS resumable upload | Unlimited size, survives drops, keeps bytes off Cloud Run | Upload through the API (32 MiB cap) |
| Eventarc triggers transcoding | Works even if the app closes after uploading | App calls "upload complete" |
| Transcoder API, HLS fMP4 | Managed, scales to zero, produces the exact ladder | FFmpeg on Cloud Run jobs (more to operate) |
| Firestore + keyword array | Serverless, no full-text engine needed for keyword + tag search | Algolia/Elastic (another service), Cloud SQL |
| Public media bucket | Players fetch segments directly from Google's edge; no API in the playback path | Signed URLs per segment |
| YAML rule files + codegen | Behaviour and contract readable and changeable without code edits; tests keep them honest | Constants in code |
| Screens as YAML (V2) | A screen is data: bricks, bindings, actions; the app checks every screen at startup and a test draws each one at four sizes, light and dark | Hand-written Dart screens |
| Activity log in Firestore | One place to see every step of an upload, a video and an order, from the API and from the app (which alone sees dropped connections) | Only Cloud Logging (not visible in the app) |
| Hashed web assets | Firebase Hosting never answers 304, so content-hashed names are the only way to cache and still show a deploy at once | `no-cache` (re-downloads 700 KB per visit) |

## 8. Everything in YAML (V2)

```
App:      routes.yml → screens/<name>.yml → bricks.yml (+ theme.yml, strings.yml, icons.yml, status.yml, art.yml)
            ScreenHost draws a screen: its `data:` source gives values, each brick binds to them and runs actions
            ({go: /path}, {back: true}, {call: name, with: value, then: …}).
Backend:  config/<domain>/*.yml → engines (pure) → services → routers
            limits, ladder and encoder, video life cycle, storage paths, listing rules, HTTP codes, event formats,
            activity log events
Infra:    infra/gcp/resources.yml → resources.py → the setup scripts (`make infra-print` = dry run)
```

- **Startup checks.** Every rule file has a schema that rejects unknown keys. The app also checks every screen: an
  unknown brick, prop, strings key, icon, role, colour, text style or route fails with the file and position, so
  the app never runs with half its config.
- **Web delivery.** `tools/web_bundle.py` packs every rule YAML into one `config.<hash>.json` (read by
  `core/config_bundle.dart`) and renames `main.dart.js` to `main.<hash>.dart.js`; both are cached for a year.
  First visit: 19 requests; repeat visit at 45 kbps: 6 KB, Home drawn in 2.4 s.

## 9. Activity log

```
API services ── record(event, product_id, order_id, **details) ──┐
                                                                 ├─→ activity_log_engine (level, group, message
App (upload controller) ── POST /logs (app events only) ─────────┘     from platform/activity_log.yml) → Firestore
                                                                        activity_log (expire_at → TTL, 14 days)
App Activity log screen ── GET /logs?group&level&product_id&cursor ── newest first, refreshed while open
```

- `record` never raises and also writes the entry to stdout, so Cloud Logging keeps every step.
- The app reports the steps only it sees (started, connection dropped, resumed, finished, failed, too long,
  cancelled), queued while offline. The server refuses its own events from the app (403).
- Entries hold ids, sizes, durations, states and reasons: never a buyer's name, an upload URL (a bearer credential),
  a token or a request body. The app reports an error's type, never its text.
- Firestore: three composite indexes `(group | level | product_id, at desc)` merged for combined filters.
