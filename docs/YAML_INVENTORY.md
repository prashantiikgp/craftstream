# Inventory: what is not YAML-driven yet

Phase 0.1 of [`YAML_PLAN.md`](YAML_PLAN.md). Taken on 2026-10-14 at commit `edf4d55` by reading the code. The
review column is for the user: **Y** move to YAML, **C** keep in code (give a reason), **D** delete.

## Already YAML-driven

| Side | Rule file | Covers |
|---|---|---|
| backend | `catalog/search.yml` | tokenising, page sizes |
| backend | `media/ladder.yml` | rungs, audio, segment length, thumbnail |
| backend | `media/upload_policy.yml` | max duration, MIME types, chunk size (served to the app by `GET /upload-policy`) |
| backend | `orders/order_rules.yml` | when a product is orderable, rounding |
| shared | `models/*.yml` | wire models, field limits, `video_status` enum, endpoint list (test-checked, not generated) |
| frontend | `ui/theme.yml`, `ui/layout.yml`, `ui/strings.yml` | tokens, size classes, all user-visible text (except below) |
| frontend | `catalog/filters.yml`, `media/player.yml`, `media/upload.yml` | featured tags and sort ids, player start rules, upload retry |

## Frontend (`frontend/lib`), about 350 items

| # | Area | Main items (file:line) | Review |
|---|---|---|---|
| F1 | Routes | `core/router.dart:26-50`: initial `/discover`, `/` redirect, 4 shell tabs, product, buy, placed, dev-only `/catalog` | |
| F2 | Navigation | `shell/shell_controller.dart:16-26`: buyer and artisan nav items and icons, "`/studio` means artisan"; `app_shell.dart:32-57`: role switch target, dev action, rail labels | |
| F3 | Inline paths | about 15 `context.go('/…')` calls in product, checkout, order placed, orders, studio, upload and discover | |
| F4 | Screen structure | every screen hard-codes section order and the spacing between sections: discover:96-112, product:41-101, product_details:18-53, checkout:84-150, order_placed:34-64, studio:33-75, upload:104-179 | |
| F5 | Screen sizes | about 45 numbers: skeleton sizes, thumb 72/88, maxLines, buy button width 180, spinner 28, slider 3/6, progress bars 4/8, flex 6/5 | |
| F6 | Icons | about 35 `Icons.*` across screens and components | |
| F7 | Tone and status maps | `ready` / `processing` / `failed` compared in about 13 places; tone maps in video_status_badge, listing_card, upload_progress:94-160, video_pick_card:74-95, notice:92-97 | |
| F8 | Components | app_button heights 36/44/52, overlay 0.08, spinner 18; status dot 6; chip padding `xs+2`; skeleton 1100 ms and 0.55 opacity; card motion curve | |
| F9 | Brand | `brand.dart:42` hard-codes `'Poppins'`; "Craft"/"Stream" text; 30-tag → motif map (:101-114); motif → colour (:129-135) | |
| F10 | Controllers | currency `'INR'` (upload_controller:190, PriceText:72); price parsing; tag split and dedupe; validation order; sort behaviour in a Dart switch (filters_engine:65-76); orders newest first | |
| F11 | Formatting | `shared/format/money.dart` (Indian grouping, symbols, minus sign), `bytes.dart` (1024, GB/MB/KB, h:mm:ss) | |
| F12 | Player | budget `50000` in player_engine:15; hls.js `startLevel 0`, `testBandwidth false`; master fetch timeout 20 s; HLS MIME; web `<video>` attrs; recover-once | |
| F13 | Upload and data | uploader status handling (200/201/308/408/429/5xx); extension → MIME map; `accept video/*`; metadata timeout 15 s | |
| F14 | Theme engine | ColorScheme and TextTheme slot mapping, component themes (app_theme:73-191); 12 contrast rules in theme_engine:156-169; `THEME_PALETTE` default duplicates `default_palette` | |
| F15 | Unused YAML | `reduced_motion_factor`, motion `medium` and `slow`, `radius.lg`, `space.section`, player `autoplay_on_product_page` and `min_buffer_to_start_seconds` | |
| F16 | Strings outside strings.yml | about 60 in the design catalog screen; `CraftStream` in app.dart and brand.dart; product card semantics label; config error screen (deliberately token-free) | |
| F17 | Env | defaults and policy in core/env.dart:42-121 (https outside dev, prod bans, `10.0.2.2`) | |
| F18 | Mock data | latency 450 ms, chunk 140 ms, processing 8 s, page size 24 (duplicate), mock policy, sample videos, 14 fixture products | |

**Bricks used by screens today:**
- **Layout and basics:** PageScroll, sliver grid, SectionHeader, AppCard (flat, elevated, interactive), AppButton,
  AppTextField, TagChip, StatusBadge, VideoStatusBadge, PriceText, Notice, EmptyState, LoadError, Skeleton.
- **Brand and product:** ProductPoster, SpotIllustration, BrandLockup, ProductCard, ListingCard.
- **Inputs and media:** QuantityStepper, SearchField, FilterBar, ProcessVideo, ProductDetails, VideoPickCard,
  UploadProgressView.
- **Small pieces:** key-value row, progress bar, divider.

## Backend (`backend/app`, `infra/gcp`, `tools`), about 130 items

| # | Area | Main items (file:line) | Review |
|---|---|---|---|
| B1 | App settings | `main.py:19` `API="/api/v1"` (duplicates endpoints.yml); title and version :26; CORS methods and headers :30-33; GZip 500 :35; log format `core/logging.py:32-39`; required-in-GCP list `settings.py:39-40` | Y: done for base path (generated from endpoints.yml), title, version, CORS, GZip (`api/http.yml`); log format and the required-in-GCP list are still code (`app.yml`, not in this pass) |
| B2 | Routes | hand-written decorators in `api/routers/*.py`, kept in step with endpoints.yml only by a test; query limits `products.py:22-25` (q 200, tag 50, cursor 100) missing from endpoints.yml; `internal.py:19` prefix duplicated 4× | Y: internal prefix done (`platform/events.yml`); mounting routes from endpoints.yml and query limits are still open |
| B3 | Errors | `core/errors.py:21-79` code ↔ status map, default messages; `order_service.py:29` `product_not_ready` is not in error_response.yml | Y: done, `api/http.yml`; error_response.yml lists every code (test-checked) |
| B4 | Video state machine | `product_repo.py:13` Literal duplicates product.yml; transitions in `media_service.py:63-94`; Transcoder states `SUCCEEDED`/`FAILED`; `"ready"` in product_repo:39,72 and order_rules_engine:18 | Y: done, `media/video_lifecycle.yml` (states test-checked against product.yml) |
| B5 | Storage layout | `infra/gcp/gcs.py:13-65`: `raw/{id}/source` and its regex, `hls/{id}/`, `manifest.m3u8`, thumbnail name, public URL, cache-control; repeated in transcoder.py:31-38 and 02_storage.sh | Y: done, `media/storage_layout.yml` (also the local upload path and sample stream) |
| B6 | Encoder | `ladder_engine.py:49-145`: `h264` key, `vbr`, `aac-he`, channel layout, `fmp4`, sprite grid, `input0`/`atom0`, baseline ≤ 240p, ffmpeg preset, maxrate ×1.2, bufsize ×2, headroom 1.1, HLS v7 | Y: done, `ladder.yml` `encoder:` (job configs and FFmpeg args unchanged); C: FFmpeg flag names and JobConfig field names are the tools' APIs |
| B7 | Catalog | `core/ids.py:10` 12-hex ids; search field map duplicates search_schema; tag order; `LIST_LIMIT=500`; collections `products` and `orders`; indexes duplicated in 03_firestore.sh | Y: done, `catalog/listing.yml`; the field map is gone (search.yml lists the fields); indexes in `infra/gcp/resources.yml` |
| B8 | Events | Pub/Sub envelope shape and error texts in `internal.py:26-47`; event type in 06_events.sh | Y: done, `platform/events.yml` (the API now also ignores other Eventarc event types) |
| B9 | Ingest | `ffprobe.py:10,19` timeout 60 s, stderr cap 200 | Y: done, `media/ingest.yml` |
| B10 | Infra | `_common.sh` names; 9 APIs; lifecycle; public media bucket; 2 CORS templates; Firestore indexes; 14 IAM bindings; Cloud Run sizing (1 CPU, 512 Mi, 0–3 instances, concurrency 40); Pub/Sub retry 30 s / 10–600 s | Y: done, `infra/gcp/resources.yml` + `resources.py` (the `.tmpl` files are gone; scripts not run yet) |
| B11 | Tools | codegen maps; local_hls sample settings; throttle proxy defaults; smoke test timeouts and payload; subset_fonts ranges and families | |
| B12 | Convention test | `tests/config_validation/test_rule_files.py` checks file trios and `extra="forbid"`; it does **not** check for literals in services or engines | Y: done, `test_literal_lint.py`; the backend baseline is empty |

**Duplicated facts to collapse:**

| Fact | Stated in | Places |
|---|---|---|
| `video_status` | product.yml, product_repo, media_service, smoke_test | 4 |
| `/api/v1` | endpoints.yml, main.py, smoke_test | 3 |
| `/internal/media/*` | endpoints.yml, internal.py, 06_events.sh ×2 | 4 |
| `raw/` and `hls/` layout | gcs.py, transcoder.py, ladder_engine.py, 02_storage.sh | 4 files |
| Firestore indexes | product_repo, 03_firestore.sh | 2 |
| Page size 24 | filters.yml, mock_store | 2 |
| Default palette | theme.yml, env.dart | 2 |
