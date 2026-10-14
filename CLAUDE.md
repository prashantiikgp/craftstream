# CraftStream

Marketplace where artisans upload a ≤15-min **process video** of a handmade product and buyers search, watch (smoothly under **50 kbps**) and order. One Flutter app (Android phone, Android tablet, Chrome) + a FastAPI backend fully on GCP.

@docs/INTENT.md

## The one architecture rule

```
YAML (human-readable rules) → Schema (validates it) → Loader (reads + caches it) → Engine (pure logic using it)
```

Every rule file gets exactly one schema, one loader and one engine, **named after the file**:

| Piece | Backend (Python) | Frontend (Dart) |
|---|---|---|
| Rules | `backend/config/<domain>/<xyz>.yml` | `frontend/assets/config/<domain>/<xyz>.yml` |
| Schema | `backend/app/schemas/<domain>/<xyz>_schema.py` | `frontend/lib/schemas/<domain>/<xyz>_schema.dart` |
| Loader | `backend/app/domain/<domain>/<xyz>_loader.py` | `frontend/lib/domain/<domain>/<xyz>_loader.dart` |
| Engine | `backend/app/domain/<domain>/<xyz>_engine.py` | `frontend/lib/domain/<domain>/<xyz>_engine.dart` |

- No generic `config_loader/` or `engines/` buckets. Loaders all call the shared `core/yaml_loader` helper.
- Schemas reject unknown keys (Pydantic `extra="forbid"`; Dart `disallowUnrecognizedKeys`). A typo in YAML must fail at startup, not at runtime.
- Engines import only their schema: no HTTP, database or GCP. That keeps them pure and trivially testable.
- A convention test (backend and frontend) fails if a YAML is missing its schema, loader, engine or engine test.
- **Everything that describes behaviour or appearance is YAML.** That covers:
  - screens (which bricks, in what order, bound to what data, doing what on tap);
  - bricks and their variants, design tokens, icons, status labels and tones;
  - routes and navigation;
  - limits, timeouts, paths, names, state machines, error codes and infra resources.
- Code is only the engine that reads it:
  - algorithms such as HLS parsing, the resumable upload and search tokenising;
  - platform glue: Firestore, GCS, Transcoder, ExoPlayer, hls.js;
  - artwork geometry.
- **No literals in screens, bricks, controllers, services or engines.** That means no colours, sizes, durations,
  paths, status strings or `Icons.*`. The literal-lint tests enforce it. Files still being migrated are listed in a
  baseline that may only shrink.
- A rule folder (`frontend/assets/config/ui/screens/*.yml`) shares one schema, loader and engine named after the
  folder in the singular (`screen_schema.dart` …).
- V2 migration plan and status: `docs/YAML_PLAN.md`.

## Data models come first

- `models/*.yml` is the **only** definition of data that crosses the wire (Product, Order, UploadTicket, …) and of the endpoints (`models/endpoints.yml`).
- *A field that isn't in `models/` does not exist.* Change the YAML first, then run `make gen`.
- `make gen` writes `backend/app/generated/models.py` and `frontend/lib/data/generated/*.dart`. **Never edit `generated/` by hand.**
- A test checks that the FastAPI routes match `models/endpoints.yml`.

## Repo map

```
models/          shared data models + endpoints (YAML) → codegen input
backend/         FastAPI service           → see backend/CLAUDE.md
frontend/        Flutter app               → see frontend/CLAUDE.md
infra/gcp/       idempotent gcloud scripts, CORS, Eventarc/Pub/Sub wiring
tools/           codegen.py, local_hls.py (FFmpeg ladder for local testing)
docs/            INTENT, PLAN, BACKEND_PLAN, FRONTEND_PLAN, ARCHITECTURE
```

## Commands

```bash
make setup     # backend/.venv + dependencies
make gen       # models/ → generated code (both sides)
make test      # all backend tests (unit, api, config validation, convention)
make api       # FastAPI on :8000, local mode (in-memory, no GCP)
make web       # Flutter web server (open in Windows Chrome)
make apk       # Android build
```

## Hard rules

1. **Video bytes never pass through the API.** The app uploads straight to GCS with a resumable URL (Cloud Run caps request bodies at 32 MiB). HLS is served from the media bucket, not the API.
2. **The player starts on the lowest rung.** Any change to the ladder or player must keep the lowest rung ≤ 50 kbps on the wire, with the player picking it first.
3. **Local mode must keep working.** `CRAFTSTREAM_MODE=local` runs the whole flow with no GCP. GCP SDKs are imported lazily.
4. **No secrets in the repo.** `.mcp.json` and config use `${ENV_VAR}` only; real values live in `.env` (gitignored) or Secret Manager.
5. **Out of scope:** shipping, payments, login/auth. The flow ends at "Order placed".
6. **Keep `make test` green** before calling a task done.
7. **Keep the plans current:** tick the checkbox in `docs/*_PLAN.md` when a task is finished.

## Environment (WSL2)

- Python venv: `backend/.venv` (not `myvenv/`, not the system Python).
- Flutter: the **Linux** SDK in `~/development/flutter`. The Windows SDK under `/mnt/d` breaks in WSL (`bash\r`); never call it.
- GCP region `asia-south1`; dedicated project `craftstream-<suffix>`; never touch other gcloud projects.
- MCP servers (`.mcp.json`): `gcloud`, `cloud-run`, `firebase` (ask before each call), `dart`, `playwright`, `context7`. GitHub work goes through the `gh` CLI.

## Where to read more

- Requirements and definition of done: `docs/INTENT.md` (imported above)
- Plans and phase checklists: `docs/PLAN.md`, `docs/BACKEND_PLAN.md`, `docs/FRONTEND_PLAN.md`
- How the system fits together: `docs/ARCHITECTURE.md`
