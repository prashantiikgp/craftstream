# CraftStream: Master Plan

Status: **S0 + S1 done** (2026-10-13). Next: B1 (backend core) and F1 (Flutter setup) in parallel.

| Plan | Covers |
|---|---|
| **PLAN.md** (this file) | requirements, architecture rule, top-level layout, shared phases, timeline, risks, tooling |
| [BACKEND_PLAN.md](BACKEND_PLAN.md) | server folders, rule files, API, GCP video pipeline, backend phases B1–B5 |
| [FRONTEND_PLAN.md](FRONTEND_PLAN.md) | Flutter folders, rule files, screens, low-bandwidth player, uploader, frontend phases F1–F6 |

---

## 1. What we are building (from `Technical_Assignment.pdf`)

| Area | Requirement | What it really forces |
|---|---|---|
| Artisan upload | Process video ≤ 15 min, **unrestricted file size**, + title/description/price | Upload must go **client → GCS directly** (resumable, chunked). Cloud Run caps request bodies at 32 MiB, so the API can never be in the byte path. 15-min limit enforced on both sides. |
| Search & discovery | Keyword + tag search/filter, video "accessible instantly" | Small JSON payloads, tiny thumbnails, player starts on the lowest rung. |
| Order | Place order; flow ends there | No shipping/fulfilment code at all. |
| Platforms | Android phone, Android tablet, Chrome web | One codebase, responsive phone/tablet layouts, a **real native APK**. |
| Bandwidth | Smooth playback **< 50 kbps** | HLS ladder with an ultra-low rung (~40 kbps incl. container overhead), fMP4 segments, player that *starts* low instead of probing high. |
| Cloud | Backend fully on **GCP** | Cloud Run + GCS + Transcoder API + Firestore + Eventarc/Pub/Sub. |
| Deliverables | Repo, architecture/GCP video, 2 demo videos (Android + Chrome, throttled) | Throttling setup and live GCP evidence are part of the build, not an afterthought. |

---

## 2. The architectural principle (carried over from hotel_agent / email_marketing)

```
YAML (human-readable rules)  →  Schema (Pydantic / Dart classes, extra=forbid)
        →  Loader (one per YAML, cached, fail-fast)  →  Engine (one per YAML, pure logic)
```

Two kinds of YAML, kept separate on purpose:

1. **Models** (`models/`): the shape of data crossing the wire, plus the endpoint list. There is one copy, shared by both sides, and `tools/codegen.py` turns it into code. *"A field that isn't in models/ does not exist."*
2. **Rules/config** (`backend/config/`, `frontend/assets/config/`): behaviour owned by one side. On the backend: bitrate ladder, upload policy, search rules, order rules. On the frontend: theme, layout breakpoints, player policy, strings.

### Naming convention: one YAML file = one schema + one loader + one engine
For every rule file `config/<domain>/<xyz>.yml`:

| Piece | Location | Job |
|---|---|---|
| YAML | `config/<domain>/<xyz>.yml` | human-readable rules |
| Schema | `app/schemas/<domain>/<xyz>_schema.py` | shape of the YAML (Pydantic, `extra="forbid"`) |
| Loader | `app/domain/<domain>/<xyz>_loader.py` | reads `<xyz>.yml`, validates it with `<xyz>_schema`, caches the result |
| Engine | `app/domain/<domain>/<xyz>_engine.py` | pure logic driven by the loaded rules |

Schemas live in their own folder (`app/schemas/`), mirroring `config/`. Each `domain/<domain>/` folder holds only loaders and engines, plus one `<domain>_service.py` that wires engines to repositories. The frontend follows the same rule with `.dart` files.

### Lessons from previous repos we fix from day one
- **email_marketing:** the same YAML lived in 3 places and drifted. Here, data models exist **once** (`models/`) and the generated code is their only consumer.
- **email_marketing:** generated TS types existed, but nothing imported them. Here, the backend and app *must* import `generated/`, and a test checks that the FastAPI routes match `models/endpoints.yml`.
- **email_marketing:** `ConfigLoader` covered only some files, and others used ad-hoc loaders. Here, every `<xyz>_loader` calls one shared helper (`core/yaml_loader.py`: read → validate → cache). A **convention test** fails if any `config/**/<xyz>.yml` lacks its `<xyz>_schema` and `<xyz>_loader`.
- **hotel_agent / email_marketing:** plaintext tokens in `.mcp.json`. Here, `.mcp.json` uses `${ENV_VAR}` expansion only (⚠ rotate the tokens in those two repos).
- **hotel_agent:** empty `ARCHITECTURE.md` and empty `core/config.py`. Write both as part of Phase 0.

---

## 3. Top-level folder structure

```
craftstream/
├── CLAUDE.md  README.md  Makefile  .mcp.json  .claude/  .vscode/
├── models/      SHARED data models: product.yml, order.yml, upload_ticket.yml, endpoints.yml → `make gen`
├── backend/     the server (details: BACKEND_PLAN.md §2)
├── frontend/    the Flutter app (details: FRONTEND_PLAN.md §2)
├── infra/gcp/   idempotent gcloud scripts, cors.json
├── tools/       codegen.py, local_hls.py, setup_flutter.sh
└── docs/        assignment PDF, these plans, ARCHITECTURE.md, decisions/
```

`backend/` and `frontend/` never import each other. They share only `models/`, through generated code:

```
models/*.yml ──make gen──┬──► backend/app/generated/models.py
                         └──► frontend/lib/data/generated/models.dart + api_client.dart
```

Both sides use the same inner pattern: `config/<domain>/<xyz>.yml` → `schemas/<domain>/<xyz>_schema` → `domain/<domain>/<xyz>_loader` + `<xyz>_engine`.

### What moves where (S0)
| Before | After | Done in |
|---|---|---|
| `specs/models/*.yaml`, `specs/api/endpoints.yaml`, `specs/build/` | `models/*.yml`, `models/endpoints.yml`, `models/build/` | S0 ✅ |
| `specs/media/ladder.yaml` | `backend/config/media/ladder.yml` | S0 ✅ |
| `transcoder/ladder.py` | `backend/app/schemas/media/ladder_schema.py` + `domain/media/ladder_loader.py` (on `core/yaml_loader.py`) | S0 ✅ |
| `transcoder/gcp_job.py` | `domain/media/ladder_engine.py` (builds the JobConfig) + `infra/gcp/transcoder.py` (submits it) | S0 ✅ |
| `transcoder/local_hls.py` | `tools/local_hls.py` (uses `ladder_engine`) | S0 ✅ |
| `backend/app/repository.py` | `backend/app/db/repositories/repository.py` (split into `product_repo` / `order_repo` in B1) | S0 ✅ |
| `backend/app/storage.py` | `backend/app/infra/gcp/gcs.py` | S0 ✅ |
| `backend/app/config.py` | `backend/app/core/settings.py` | S0 ✅ |
| `backend/tests/*.py` | `backend/tests/api/`, `backend/tests/unit/media/` | S0 ✅ |
| `app/` (+ `lib/generated/`) | `frontend/` (+ `lib/data/generated/`) | S0 ✅ |
| `doc/` | `docs/` | S0 ✅ |
| `pyproject.toml`, `requirements-dev.txt` (root) | `backend/`; Python imports are now `app.*` | S0 ✅ |
| `myvenv/` (root) | `backend/.venv` (gitignored) | S0 ✅ |
| `backend/app/main.py` (all routes in one file) | `api/routers/*` + `domain/*/<domain>_service.py` | B1 |
| search logic inside `main.py` / `repository.py` | `config/catalog/search.yml` + `search_schema` / `search_loader` / `search_engine` | B2 |

---|---|
| `specs/models/*.yaml`, `specs/api/endpoints.yaml`, `specs/build/` | `models/*.yml`, `models/endpoints.yml`, `models/build/` |
| `specs/media/ladder.yaml` | `backend/config/media/ladder.yml` |
| `transcoder/ladder.py` | split into `backend/app/schemas/media/ladder_schema.py` + `domain/media/ladder_loader.py` |
| `transcoder/gcp_job.py` | `domain/media/ladder_engine.py` (builds the JobConfig) + `infra/gcp/transcoder.py` (submits it) |
| `transcoder/local_hls.py` | `tools/local_hls.py` |
| `backend/app/main.py` (all routes in one file) | split into `api/routers/*` + `domain/*/<domain>_service.py` |
| search logic inside `main.py` / `repository.py` | `config/catalog/search.yml` + `search_schema` / `search_loader` / `search_engine` |
| `backend/app/repository.py` | `backend/app/db/repositories/` |
| `backend/app/storage.py` | `backend/app/infra/gcp/gcs.py` |
| `backend/app/config.py` | `backend/app/core/settings.py` |
| `app/` | `frontend/` |
| `doc/` | `docs/` |
| `pyproject.toml`, `requirements-dev.txt` (root) | `backend/` |
| `myvenv/` (root) | `backend/.venv` (gitignored); Makefile and VS Code already expect `.venv` |

---

## 4. End-to-end data flow (target)

```
Artisan app ──POST /products──────────────► Cloud Run API ── Firestore: product(status=awaiting_upload)
     │◄──── resumable GCS session URL ──────┘
     │── PUT chunks (resume on drop) ──────► GCS uploads bucket  raw/<id>/source
                                                 │ object.finalize (Eventarc)
                                                 ▼
                                   Cloud Run /internal/media/uploaded
                                     ladder_engine → Transcoder job (editList caps at 15:00)
                                                 │ job done (Pub/Sub)
                                                 ▼
                                   Cloud Run /internal/media/transcoded → status=ready, hls_url
Buyer app ──GET /products?q=&tag=──► search_engine (rules from catalog/search.yml)
          ──HLS manifest + fMP4 ───► GCS media bucket (public read, CORS, optional Cloud CDN)
          ──POST /orders ──────────► order_engine (rules from orders/order_rules.yml) → done
```
Eventarc replaces the app calling `upload-complete`: if the app dies after the upload, transcoding still starts.

---

## 5. Phases and timeline

Shared phases come first. Then backend and frontend run **in parallel**: the app is built against the backend's local (in-memory) mode and only needs GCP at the end.

```
S0 Restructure + tooling ─► S1 Data models ─┬─► B1 core ─► B2 rule files ─► B3 50 kbps proof ─► B4 GCP ─► B5 harden ─┐
                                            │                  │ (local API ready)                                   ├─► S2 Deliver
                                            └─► F1 setup ─► F2 rule files ─► F3 data ─► F4 screens ─► F5 player ─► F6 builds ─┘
```

### S0: Restructure + tooling (shared)
- [x] Move files into the new layout (§3 and the table below); `make test` green
- [x] Root `CLAUDE.md` + `docs/INTENT.md`; `backend/CLAUDE.md`; `frontend/CLAUDE.md`
- [x] `myvenv/` → `backend/.venv`; Makefile targets updated
- [x] `.vscode/` (extensions, launch, tasks), `.mcp.json` (secrets via `${ENV}`), `.claude/settings.json`, `backend/requests.http`
- [x] Linux Flutter SDK, JDK 17, Android SDK, FFmpeg, Firebase CLI installed in WSL (`flutter doctor`: no issues)

### S1: Data models (shared)
- [x] `models/`: Product, Order, UploadTicket, UploadPolicy, ErrorResponse, paged product list
- [x] `models/endpoints.yml`: the API table in BACKEND_PLAN §4
- [x] `make gen` updates both sides; test: FastAPI routes == `endpoints.yml`

### Backend B1–B5 → [BACKEND_PLAN.md §6](BACKEND_PLAN.md) · Frontend F1–F6 → [FRONTEND_PLAN.md §5](FRONTEND_PLAN.md)

### S2: Deliver (shared)
- [ ] README for reviewers: architecture diagram, how to run, live URLs
- [ ] Recording 1: architecture + live GCP evidence (Cloud Run, Transcoder jobs, buckets, Firestore)
- [ ] Recording 2: Android app flow, throttled < 50 kbps
- [ ] Recording 3: Chrome flow, throttled < 50 kbps
- [ ] Email hiring@devdolphins.com (CC boxvamsee@gmail.com) with the repo + 3 videos

---

## 6. Things to keep in mind (risks I already see)

1. **The player picks the rung, not the ladder.** ExoPlayer (Android) and hls.js (web) start from a default bandwidth estimate that is far above 50 kbps, so they fetch a high-rung segment first and stall. Plan: `player.yml` + `player_engine` force a low start (hls.js `startLevel: 0`, a capped initial bitrate estimate). If the stock `video_player` plugin cannot expose that, we serve a second "low-band" master manifest that lists only the bottom rungs.
2. **Flutter web app shell is ~2 MB.** At 50 kbps that takes minutes. For the demo, load the app first and then switch on throttling (the requirement is about *playback*). Also cache the shell with the service worker so reloads are instant.
3. **Large uploads on Flutter web.** By default `file_picker` reads the whole file into memory on web. Use `withReadStream: true` and push chunks to the GCS resumable session.
4. **15-minute limit.** Check the duration on the client before uploading (UX), and on the server cap it with a Transcoder `editList` end offset of 900 s (enforcement). Both values come from `upload_policy.yml`.
5. **GCS CORS.** Two buckets need it: the uploads bucket (`PUT` from the Chrome origin) and the media bucket (`GET` for hls.js). These go in `infra/gcp/cors.json`.
6. **Search on Firestore.** It has no full-text search. We keep the `keywords` token array plus `array-contains`. That is enough for "keywords + tags"; the rules (fields, stopwords, prefix match) live in `catalog/search.yml`.
7. **Region.** `asia-south1` is the default. Check that the Transcoder API is available there before Phase 4; if not, use `asia-southeast1`.
8. **Use a dedicated GCP project.** gcloud currently points at `gen-lang-client-0079237148`. Create `craftstream-<suffix>` so the GCP evidence video shows only this project's services.
9. **Throttling for the demos.** In Chrome, add a DevTools custom profile of 45 kbps down and 45 kbps up. On the Android emulator, use the `-netspeed` option or Extended Controls → Cellular → GPRS/EDGE. Prove the throttle on screen, for example with a network speed overlay.

---

## 7. Local tooling to install (WSL)

| Tool | Status | Why |
|---|---|---|
| **Flutter SDK (Linux)** | ✓ 3.47.7 stable in `~/development/flutter` (ahead of `/mnt/d` via `~/.bashrc`) | Android + web builds from WSL |
| JDK 17 + Android SDK | ✓ OpenJDK 17; `~/development/android-sdk`: platform-tools, android-36, build-tools 37 | Build the APK in WSL |
| Android emulator / device | — (F1) | Run the emulator on Windows (Android Studio) or use a phone over `adb connect` (Wi-Fi) |
| FFmpeg | ✓ 6.1.1 (apt; **no `libfdk_aac`**, so local HE-AAC falls back to AAC-LC) | Local ladder build + bitrate proof (`tools/local_hls.py`) |
| Google Chrome (Windows) | ✓ | `flutter run -d web-server` from WSL, open in Windows Chrome |
| gcloud | ✓ 563.0.0 | still to do: `gcloud auth application-default login` (cloud-run MCP + local GCP mode) |
| Firebase CLI | ✓ 15.33.0 (npm global) | web hosting + Firebase MCP |
| Docker | ✓ 29.1 | local Cloud Run image test |
| uv | ✓ 0.9.16 | fast venv/installs for backend |
| gh | ✓ 2.40, logged in | repo/PR work (replaces GitHub MCP) |

## 8. VS Code extensions (`.vscode/extensions.json`)

Already listed: Remote-WSL, Python, Pylance, Ruff, YAML (Red Hat), Dart, Flutter, Google Cloud Code.
Add:
- `ms-azuretools.vscode-containers`: Dockerfile and image tooling
- `tamasfe.even-better-toml`: `pyproject.toml`
- `usernamehw.errorlens`: inline errors
- `humao.rest-client`: `.http` files to exercise the API
- `eamodio.gitlens`: optional
- `redhat.vscode-yaml` with a JSON-schema mapping, so models and config YAML get autocomplete and validation in the editor (we emit JSON Schema from the Pydantic schemas)

## 9. MCP servers (`.mcp.json`, secrets via `${ENV}` only)

| Server | Why for this project |
|---|---|
| **Dart & Flutter MCP** (`dart mcp-server`, Dart ≥ 3.9) | analyze/fix, pub, run tests, hot-reload, widget tree inspection |
| **gcloud MCP** (`@google-cloud/gcloud-mcp`) | create buckets, IAM, Eventarc, read logs, all from the session |
| **Cloud Run MCP** (`@google-cloud/cloud-run-mcp`) | deploy and inspect services |
| **Firebase MCP** (`firebase-tools mcp`) | Firestore data inspection, Hosting deploy |
| **Playwright MCP** (`@playwright/mcp`) | drive the Chrome web flow end to end, screenshots, throttled runs |
| **Context7** (`@upstash/context7-mcp`) | current docs for Flutter, FastAPI, Transcoder API, hls.js |
| ~~GitHub MCP~~ → `gh` CLI | already logged in, so no token goes in any config |
| Tavily (already user-level) | web research |

Versions are pinned in `.mcp.json`. GCP/Firebase MCP tools need approval per call (`.claude/settings.json` → `ask`); destructive gcloud commands are denied.
