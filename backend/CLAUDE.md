# Backend: FastAPI on Cloud Run

Read with the root `CLAUDE.md`. Full plan: `docs/BACKEND_PLAN.md`.

## Layers

| Layer | Folder | May | Must not |
|---|---|---|---|
| Rules | `config/<domain>/<xyz>.yml` | hold tunable behaviour | contain secrets or env-specific values |
| Schemas | `app/schemas/<domain>/<xyz>_schema.py` | define Pydantic models (`extra="forbid"`) | contain logic |
| Loaders | `app/domain/<domain>/<xyz>_loader.py` | call `core.yaml_loader.load_yaml`, cache with `lru_cache` | do anything else |
| Engines | `app/domain/<domain>/<xyz>_engine.py` | pure functions/classes over loaded rules | import FastAPI, repositories, `infra/` or GCP |
| Services | `app/domain/<domain>/<domain>_service.py` | wire engines + repositories + `infra/gcp` | know about HTTP (no `Request`, no `HTTPException`) |
| Routers | `app/api/routers/*.py` | register typed handlers by endpoint name (`@endpoints.handler("getOrder")`), call one service, return a generated model | declare paths, methods, statuses or query limits (those are `models/endpoints.yml`); contain business rules |
| Repositories | `app/db/repositories/` | Protocol + InMemory + Firestore implementations | contain business rules |
| GCP wrappers | `app/infra/gcp/` | thin wrappers over Google SDKs (lazy imports) | be imported by engines |
| Local fakes | `app/infra/local/` | same methods as the GCP wrappers, no network | be used in gcp mode |
| Wiring | `app/api/deps.py` | `build_container(settings)` picks GCP or local parts; `*Dep` types for routers | hold logic |
| Generated | `app/generated/models.py`, `api.py` (base path + endpoint table) | be imported everywhere | be edited by hand |

**Dependency direction:** `routers → services → engines`; services also use `repositories` and `infra/`. Never the other way. `tests/config_validation/test_architecture.py` enforces this by reading imports.

## Modes

- `CRAFTSTREAM_MODE=local`: InMemory repositories, `LocalStorage` (fake resumable upload target at `/local-upload/{id}`) and `LocalTranscoder` (finishes instantly). No GCP credentials needed.
- `CRAFTSTREAM_MODE=gcp`: Firestore, GCS, Transcoder. Import Google SDKs **inside** the functions that use them so local mode and tests never need them.
- Only `build_container` looks at the mode. Services never branch on it; they call the ports (`Storage`, `Transcoder`).

## Recipe: add a rule file

1. `config/<domain>/<xyz>.yml`
2. `app/schemas/<domain>/<xyz>_schema.py`:
   ```python
   class XyzRules(BaseModel):
       model_config = ConfigDict(extra="forbid", frozen=True)
       ...
   ```
3. `app/domain/<domain>/<xyz>_loader.py`:
   ```python
   @lru_cache(maxsize=1)
   def load_xyz_rules() -> XyzRules:
       return load_yaml("<domain>/<xyz>.yml", XyzRules)
   ```
4. `app/domain/<domain>/<xyz>_engine.py`: takes `XyzRules` as an argument (defaulting to the loader), so tests can pass their own rules.
5. `tests/unit/<domain>/test_<xyz>_engine.py`. The config-validation and convention tests pick the YAML up automatically.
6. `make gen`: writes `config/.schemas/<domain>/<xyz>.schema.json` and adds the `# yaml-language-server: $schema=...` first line, so VS Code validates the YAML as you type.

YAML gotcha: bare `on`, `off`, `yes`, `no` are booleans. Quote them in string lists.

## Recipe: add an endpoint

`models/endpoints.yml` is the only place a route is declared: name, method, path, success status, body and return
models, query params with their limits, `mode: local` for local-only ones. `public` endpoints (under `base_path`)
are in the Dart client and `/docs`; `internal` ones are neither.

1. Add it (and any new types) to `models/endpoints.yml` / `models/*.yml`
2. `make gen` (writes the endpoint table in `app/generated/api.py` and the Dart client)
3. Service method in `app/domain/<domain>/<domain>_service.py`
4. Handler in `app/api/routers/<x>.py`, registered by name and typed with the generated models:
   ```python
   @endpoints.handler("listProducts")
   def list_products(catalog: CatalogDep, q: str | None = None, limit: int | None = None) -> ProductPage:
   ```
   Query params are plain `T | None = None`; their limits come from the YAML. A new router module also goes in
   `mount(...)` in `app/main.py`. `app/api/endpoints.py` refuses, at import, a handler whose name, path params,
   query params, body or return type disagree with the YAML, and `mount` refuses to start if an endpoint has no
   handler.
5. `tests/api/` test. The routes test checks every endpoint has exactly one handler and nothing else is mounted.

## Tests

- `tests/unit/<domain>/`: engines, pure and fast, no fixtures beyond rules
- `tests/api/`: routes == `endpoints.yml` and `/openapi.json`; `client` fixture (`tests/conftest.py`) = fresh app + fresh in-memory data per test; build a custom `Container` to swap a part (see `test_internal.py`)
- `tests/config_validation/`:
  - every YAML loads; naming convention (schema, loader, engine and engine test per rule file);
  - **literal lint** (`test_literal_lint.py`): no status strings, storage paths, collection names or tunable
    numbers in Python. Files still being migrated are in `literal_baseline.yml`, which may only shrink.
- Bitrate budget test (needs FFmpeg; skipped with a clear reason if it's missing)
- Run: `make test` from the repo root

## GCP notes

- `/internal/*` is called only by Eventarc and Pub/Sub. Verify the OIDC token and the expected service account; reject everything else.
- Upload bucket: private, CORS `PUT` from the web origin. Media bucket: public read, CORS `GET`, `Cache-Control` on HLS objects.
- The 15:00 cap is a Transcoder `editList` end offset taken from `upload_policy.yml`.
- Logs are structured JSON (`core/logging.py`) so Cloud Logging can filter them.
- **Activity log** (`GET`/`POST /logs`, Firestore `activity_log`, TTL on `expire_at`): every event, its level, group,
  source and message template is declared in `config/platform/activity_log.yml`. Services call
  `activity.record("<event>", product_id=..., **details)`, which never raises and also writes to stdout. The app may
  only post `source: app` events. Details hold ids, sizes, durations, states and reasons: **never** a buyer's name,
  an upload URL (a bearer credential), a token or a request body.

## Style

Python 3.12, type hints everywhere, ruff (line length 120), one `ErrorResponse` shape for every error. Services raise `NotFound` / `Conflict` / `DomainError` from `core/errors.py`; the HTTP status mapping lives there only. Log with `logging.getLogger(__name__)` and `extra={...}` fields.
