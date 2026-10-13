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
| Routers | `app/api/routers/*.py` | parse request, call one service, return a generated model | contain business rules |
| Repositories | `app/db/repositories/` | Protocol + InMemory + Firestore implementations | contain business rules |
| GCP wrappers | `app/infra/gcp/` | thin wrappers over Google SDKs | be imported by engines |
| Generated | `app/generated/models.py` | be imported everywhere | be edited by hand |

**Dependency direction:** `routers → services → engines`; services also use `repositories` and `infra/gcp`. Never the other way.

## Modes

- `CRAFTSTREAM_MODE=local`: InMemory repositories; the uploads router exposes a fake upload target that calls `media_service.on_uploaded()`, and transcoding is simulated. No GCP credentials needed.
- `CRAFTSTREAM_MODE=gcp`: Firestore, GCS, Transcoder. Import Google SDKs **inside** the functions that use them so local mode and tests never need them.

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

## Recipe: add an endpoint

1. Add it (and any new types) to `models/endpoints.yml` / `models/*.yml`
2. `make gen`
3. Service method in `app/domain/<domain>/<domain>_service.py`
4. Router function in `app/api/routers/`, typed with the generated models
5. `tests/api/` test. The routes-match-endpoints test fails until steps 1–4 agree.

## Tests

- `tests/unit/<domain>/`: engines, pure and fast, no fixtures beyond rules
- `tests/api/`: FastAPI `TestClient` in local mode, full flows
- `tests/config_validation/`: every YAML loads; naming convention; routes == `endpoints.yml`
- Bitrate budget test (needs FFmpeg; skipped with a clear reason if it's missing)
- Run: `make test` from the repo root

## GCP notes

- `/internal/*` is called only by Eventarc and Pub/Sub. Verify the OIDC token and the expected service account; reject everything else.
- Upload bucket: private, CORS `PUT` from the web origin. Media bucket: public read, CORS `GET`, `Cache-Control` on HLS objects.
- The 15:00 cap is a Transcoder `editList` end offset taken from `upload_policy.yml`.
- Logs are structured JSON (`core/logging.py`) so Cloud Logging can filter them.

## Style

Python 3.12, type hints everywhere, ruff (line length 120), one `ErrorResponse` shape for every error, domain errors mapped to HTTP in `core/errors.py` only.
