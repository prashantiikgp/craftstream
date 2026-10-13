# CraftStream: Backend Plan

Part of the [master plan](PLAN.md). Frontend: [FRONTEND_PLAN.md](FRONTEND_PLAN.md).

**Stack:** Python 3.12 · FastAPI · Pydantic v2 · Firestore · Cloud Storage · Transcoder API · Eventarc/Pub/Sub · Cloud Run

---

## 1. What the backend is responsible for

| Job | How |
|---|---|
| Create a product listing | Store it in Firestore with `video_status=awaiting_upload` and return a **resumable GCS upload URL** |
| Receive the video | It doesn't: the app uploads **straight to GCS**. Cloud Run rejects request bodies over 32 MiB, so video bytes never touch the API. |
| Transcode | When GCS reports the upload finished (Eventarc), build a Transcoder job from `ladder.yml` (144p @ ~40 kbps up to 720p, HLS fMP4) and cap it at 15:00 |
| Mark the video ready | When the Transcoder reports the job done (Pub/Sub), set `video_status=ready` and `hls_url` |
| Search | Keyword + tag search over **ready** products, with rules from `search.yml` |
| Orders | Validate, compute the total, save. The flow ends there. |
| **Not** the backend's job | Streaming video (GCS serves HLS directly), shipping, payments, auth |

---

## 2. Folder structure

```
backend/
├── pyproject.toml  requirements.txt  requirements-dev.txt  Dockerfile  .env.example  CLAUDE.md
├── config/                              ① RULES (YAML), one folder per domain
│   ├── catalog/search.yml
│   ├── media/ladder.yml
│   ├── media/upload_policy.yml
│   └── orders/order_rules.yml
├── app/
│   ├── main.py                          app factory: create FastAPI, add middleware, include routers
│   ├── core/                            plumbing
│   │   ├── settings.py                  env vars (pydantic-settings): mode, project, buckets, region
│   │   ├── yaml_loader.py               shared helper: read YAML → validate with schema → cache
│   │   ├── errors.py                    domain errors → HTTP errors
│   │   └── logging.py                   structured JSON logs (readable in Cloud Logging)
│   ├── schemas/                         ② SCHEMAS, mirrors config/
│   │   ├── catalog/search_schema.py
│   │   ├── media/ladder_schema.py  media/upload_policy_schema.py
│   │   └── orders/order_rules_schema.py
│   ├── domain/                          ③ LOADERS + ENGINES (+ one service per domain)
│   │   ├── catalog/  search_loader.py  search_engine.py  catalog_service.py
│   │   ├── media/    ladder_loader.py  ladder_engine.py
│   │   │             upload_policy_loader.py  upload_policy_engine.py  media_service.py
│   │   └── orders/   order_rules_loader.py  order_rules_engine.py  order_service.py
│   ├── api/                             ④ HTTP layer (thin)
│   │   ├── deps.py                      gives routers their services/repos
│   │   └── routers/  products.py  orders.py  uploads.py  internal.py  health.py
│   ├── db/repositories/                 ⑤ storage: product_repo.py, order_repo.py
│   │                                    (Protocol + InMemory for local/tests + Firestore for GCP)
│   ├── infra/gcp/                       ⑥ thin Google SDK wrappers: gcs.py, transcoder.py
│   └── generated/models.py              ⑦ from /models (never edit by hand)
└── tests/
    ├── unit/<domain>/test_<xyz>_engine.py
    ├── api/                             full flows + "routes == models/endpoints.yml"
    └── config_validation/               every YAML loads; naming convention holds
```

**Dependency direction:** `routers → services → engines`. Services also use `repositories` and `infra/gcp`. Engines import only their schema, never HTTP, the database or GCP, which keeps them trivially testable.

---

## 3. Rule files: YAML → schema → loader → engine

| YAML | Engine's job | Example rules inside |
|---|---|---|
| `catalog/search.yml` | `search_engine`: build keyword tokens for a product; match a query + tag | searchable fields, stopwords, min token length, prefix match on/off |
| `media/ladder.yml` | `ladder_engine`: turn the rungs into a Transcoder `JobConfig` (and FFmpeg args for local runs); check the lowest rung's bitrate budget | rungs (size, fps, kbps), segment length, codec, `max_lowest_rung_total_kbps: 50` |
| `media/upload_policy.yml` | `upload_policy_engine`: check mime types; produce the 15:00 `editList` cap; set the chunk size sent to the app | `max_duration_seconds: 900`, allowed mime types, `chunk_size_mb` |
| `orders/order_rules.yml` | `order_rules_engine`: validate quantity; compute the total with rounding | qty min/max, currency, rounding mode |

Every loader looks the same:
```python
# domain/catalog/search_loader.py
@lru_cache(maxsize=1)
def load_search_rules() -> SearchRules:
    return load_yaml("catalog/search.yml", SearchRules)   # core/yaml_loader.py
```

---

## 4. API (defined in `models/endpoints.yml`)

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/v1/products` | Create a listing → `UploadTicket` (product + resumable upload URL + chunk size) · 201 |
| GET | `/api/v1/products?q=&tag=&cursor=&limit=` | Search ready products → `ProductPage` of `ProductSummary` (no description) |
| GET | `/api/v1/products/{id}` | Product details + `video_status` + `hls_url` (the app polls this while transcoding runs) |
| GET | `/api/v1/tags` | `TagList` for the filter chips, most used first |
| GET | `/api/v1/upload-policy` | The app's pre-upload check (15 min, file types). Read from the **same YAML**, so the rule is defined once. |
| POST | `/api/v1/orders` | Place an order → `Order(status=placed)` |
| POST | `/internal/media/uploaded` | Eventarc: an upload finished → start transcoding *(not public)* |
| POST | `/internal/media/transcoded` | Pub/Sub: a transcode finished → mark ready or failed *(not public)* |
| GET | `/healthz` | Liveness |
| PUT | `/local-upload/{id}` | **Local mode only.** Fake GCS resumable target (Content-Range chunks → 308 + `Range` until the last) |

Every error is an `ErrorResponse` (`code`, `message`, `details`). The route test checks method, path **and** success status against `models/endpoints.yml` (public `endpoints` + `internal`), both ways.

`upload-complete` from the scaffold is gone: Eventarc fires even if the app closes right after the upload. In **local mode**, `/local-upload/{id}` speaks the same resumable protocol as GCS and calls the same `on_uploaded()`, so the app's uploader is tested against the real protocol on a laptop.

---

## 5. Video pipeline on GCP

```
gs://<proj>-uploads/raw/<id>/source  ──finalize──► Eventarc ──► /internal/media/uploaded
                                                                   ladder_engine → Transcoder job
gs://<proj>-media/hls/<id>/manifest.m3u8 ◄── Transcoder ──done──► Pub/Sub ──► /internal/media/transcoded
            (public read + CORS)                                                     status=ready
```

---

## 6. Phases and tasks

### B1: Core skeleton (local, no GCP)
- [x] `core/settings.py`, `core/yaml_loader.py`, `core/errors.py` (S0/S1)
- [ ] `core/logging.py`
- [ ] `main.py` as an app factory; split the current all-in-one `main.py` into `api/routers/*`
- [ ] `db/repositories/`: `ProductRepo`/`OrderRepo` Protocols + InMemory versions
- [ ] Services: `catalog_service`, `media_service`, `order_service`
- [ ] Done when the existing API tests pass on the new structure

### B2: Rule files (the pattern, ×4)
- [x] `ladder`: YAML + `_schema` + `_loader` + `_engine` (done in S0, with `core/yaml_loader.py`)
- [x] `upload_policy`: YAML + `_schema` + `_loader` + `_engine` (done in S1; the 15:00 cap is an `editList` in the Transcoder job)
- [ ] For `search` and `order_rules`: YAML + `_schema` + `_loader` + `_engine` (moves page size and total rounding out of `main.py`)
- [ ] Unit tests per engine (`tests/unit/<domain>/`)
- [ ] Export JSON Schema from each `<xyz>_schema` and map it in `.vscode/settings.json` (`yaml.schemas`) so rule YAML gets autocomplete
- [ ] `config_validation`: every YAML loads; **convention test**: each `xyz.yml` has `xyz_schema` + `xyz_loader`
- [x] New endpoints: `/tags`, `/upload-policy`; pagination on the list endpoint (done in S1)
- [ ] Done when the full artisan → buyer → order flow works in `/docs` in local mode

### B3: Prove the 50 kbps budget locally
- [ ] Install FFmpeg; `tools/local_hls.py` builds the ladder **using `ladder_engine`** (same rules as GCP)
- [ ] Test: encode a sample clip and assert that the lowest rung's on-the-wire bitrate (segments + playlists) stays ≤ 50 kbps
- [ ] Done when the number is measured and recorded in `docs/ARCHITECTURE.md`

### B4: GCP
- [ ] New project `craftstream-<suffix>`; enable APIs: Run, Storage, Firestore, Transcoder, Eventarc, Pub/Sub, Cloud Build, Artifact Registry
- [ ] Check that the Transcoder API is available in `asia-south1` (fall back to `asia-southeast1`)
- [ ] Buckets: `uploads` (private, CORS `PUT` from the web origin, lifecycle: delete raw files after N days) and `media` (public read, CORS `GET`)
- [ ] Firestore (Native) + `FirestoreRepo`
- [ ] Service accounts: the API (Storage, Firestore, Transcoder); Eventarc/Pub/Sub invoker; **verify OIDC tokens** on `/internal/*`
- [ ] Wire `infra/gcp/transcoder.py`, the Eventarc trigger and the Pub/Sub push subscription
- [ ] Deploy to Cloud Run with `gcloud run deploy --source` (scripts in `infra/gcp/`, idempotent)
- [ ] Done when a real 15-min upload goes uploads bucket → transcode → `ready` → HLS plays from the media bucket

### B5: Hardening + evidence
- [ ] gzip responses, small payloads (no description in list results), `Cache-Control` on HLS objects
- [x] Errors: one `ErrorResponse` shape everywhere (`core/errors.py`, done in S1)
- [ ] Smoke test against the deployed URL
- [ ] GCP evidence checklist for the video: Cloud Run revisions + logs, the Transcoder job list, bucket contents, Firestore docs

---

## 7. Definition of done (backend)
- Deployed on Cloud Run and reachable from the web and Android app
- A 15-min video uploaded from the app transcodes automatically; the lowest rung measures ≤ 50 kbps
- Search by keyword and tag returns only ready products
- An order is placed and stored
- `make test` is green: unit, API, config validation, convention, bitrate budget
