# V2 plan: everything YAML-driven, theme B

Status: **Phase 1 in progress** (2026-10-14). Done: Phase 0; theme B; every user screen is screen YAML (Home, Browse,
Product, Checkout, Order placed, Your orders, Your products, New product/Uploading); the v1 shell is gone.
Live: https://craftstream-qi0tvg.web.app (V2 build; v1 is the previous release in Firebase Hosting history).
Inventory of what is hard-coded today: [`YAML_INVENTORY.md`](YAML_INVENTORY.md).
Look and screens: the "CraftStream new look" canvas, rows **B dark** and **B light**.

## Why

The architecture rule says behaviour and appearance live in YAML and code is only the engine. Today only
10 rule files exist (6 frontend, 4 backend). Routes, navigation, screen layouts, components, status maps,
error handling, storage paths, the video state machine and all infra names are hard-coded. The inventory
counts about 350 frontend items and about 130 backend items.

**Goal:** someone reading only the YAML can tell what every screen shows, in what order and style, where
every button goes, and every rule the backend applies. Dart and Python read the YAML and do the work.

## Principles (apply to every phase)

1. **One rule file → one schema → one loader → one engine**, named after the file (unchanged). Unknown keys fail
   at startup.
2. **YAML says *what*, code says *how*.**
   - YAML holds: screen composition, ordering, sizes, colours, text keys, icons by semantic name, routes,
     limits, timeouts, state machines, names and paths.
   - Code holds:
     - algorithms: HLS parsing, resumable upload, token bucket, search tokenising;
     - platform glue: Firestore, GCS, Transcoder, ExoPlayer, hls.js;
     - artwork geometry.
3. **No literal in a screen, brick, controller, service or engine.** That covers colours, sizes, durations,
   paths, status strings and icons. A lint test enforces it. The allowed exceptions are listed in the test,
   each with a reason.
4. **One source per fact.** The inventory's duplicates go:
   - `video_status` is stated in 4 places;
   - `/api/v1` in 3;
   - `/internal/media` in 4;
   - the `raw/` and `hls/` path layouts in 4 files;
   - the Firestore indexes in 2.
5. **Local mode keeps working** (`CRAFTSTREAM_MODE=local`, `MOCK_DATA=true`).
6. **Tests in batches** (per folder, `--concurrency=1`) at every step.
7. **The < 50 kbps behaviour must not regress.** Lowest rung first, small posters, no autoplay in grids.

---

## Phase 0: Investigation and groundwork

Sets up what every later phase needs, so Phases 1 and 2 are mostly "move the literal into YAML".

### 0.1 Investigation
- [x] Inventory the hard-coded behaviour in the frontend and backend (`YAML_INVENTORY.md`).
- [x] Mock up theme B: dark and light (#F5F5F5); home, browse, product, checkout, order placed, your orders.
- [x] Mock up theme B for the artisan side, in dark: Your products (listing cards with status), New product
      (form, video pick) and Uploading (progress and the four steps). The light versions come from the same
      tokens. *(Awaiting user approval.)*
- [ ] Mock up theme B for tablet landscape and desktop: home with doors side by side; browse with 4–5 columns;
      product with video and details side by side.
- [x] Mock up the missing entry points *(awaiting user approval)*:
  - where a buyer opens **Your orders** without placing a new order (a header action on Browse and Product,
    plus a link under the doors on Home);
  - where the **light/dark toggle** sits;
  - how Sell switches back to Buy.
- [ ] Review the inventory with the user: mark each item **move to YAML**, **keep in code (reason)** or
      **delete**.

### 0.2 Decisions (decided 2026-10-14)
- [x] **D1, screen files:** `assets/config/screens/*.yml`, one file per screen, all validated by one
      `screen_schema` / `screen_loader` / `screen_engine`. The convention test learns "rule folders".
      *(Default; the user did not object.)*
- [x] **D2, bricks:** one `ui/bricks.yml` with every brick's variants and sizes; one schema class per brick in
      `brick_schema.dart`. *(Default.)*
- [x] **D3, depth: bricks plus named variants (user).** YAML picks the bricks, their order, props, bindings,
      actions and per-size-class layout. A brick's inner layout is a named variant defined in `bricks.yml`.
      There is no general row/column/padding language.
- [x] **D4, theme B only (user).** Drop the saffron, terracotta and marigold palettes and directions A and C.
      Theme B, light (#F5F5F5) and dark, is the only look.
- [x] **D5, infra:** `infra/gcp/resources.yml` drives the scripts through a Python reader. It is done last
      (2.3), with a dry run and the user's OK before applying. *(Default.)*
- [x] **D6, V2 first (user).** The submission waits for V2, and the demos are recorded from V2. Safety net:
      tag `v1.0` on the last v1 commit (`edf4d55`) and work on branch `v2-yaml`, so a working build exists if
      V2 runs late.
- [x] **D7, orders survive a restart (user):** keep the order ids on the device and add
      `GET /orders/{order_id}`. The backend redeploy needs the user's OK at the time.
- [x] **D8, deploys:** ask before every GCP or Firebase deploy in V2.
- [x] **D9, fonts:** Space Grotesk and Space Mono, bundled and subset. *(Default.)*
- [x] **D10, inventory review:** Claude fills the Y/C/D column; the user checks only the C (keep in code) rows.

### 0.3 Groundwork (code)
- [x] Branch `v2-yaml`; tag `v1.0` on the current head.
- [x] Update the root, frontend and backend `CLAUDE.md`: the rule becomes "everything YAML". Add the
      "what stays in code" list from Principle 2.
- [ ] **Convention tests, both sides:**
  - [x] **Create the frontend convention test.** None exists today; only the backend has
        `test_rule_files.py`, although the root CLAUDE.md says both sides have one. Every
        `assets/config/**.yml` needs its schema, loader, engine and engine test, and must be listed in
        `pubspec.yaml`.
  - [x] Rule folders (D1): each file in a rule folder needs the folder's schema, loader and engine.
  - [x] **Screen render test:** every `screens/*.yml` builds without error in every size class, in light and
        dark, with mock data. Every brick name, binding path and action in it must resolve. This replaces the
        compile-time checks we lose when screens leave Dart.
  - [x] Literal lint (frontend): no `Color(`, `Icons.`, numeric sizes or `Duration(` in `lib/features/**` and
        `lib/shared/bricks/**`. Baseline at the start: about 180 literals in 26 files (`literal_baseline.yml`).
  - [x] Literal lint (backend): no status strings, paths or collection names in `app/domain/**/*_service.py`
        and `app/infra/**`. Baseline at the start: 52 literals in 13 files.
  - [ ] Every engine has a unit test file (backend check, mirrored in Dart).
- [ ] **Editor support:**
  - Export JSON Schemas for the frontend YAML too, like `backend/config/.schemas` does.
  - Add a `# yaml-language-server: $schema=` modeline to every rule file, so VS Code autocompletes and flags
    typos while you edit.
- [x] **Frontend engines** (built as `routes_engine`, `screen_engine` + `bricks_engine`, `navigation_engine`, `icons_engine`,
      `status_engine`, `art_engine`; bricks in `lib/shared/bricks/bricks.dart`):
  - [x] `route_engine`: builds the GoRouter from `app/routes.yml`.
  - [x] `screen_engine`: resolves a screen YAML to a brick tree per size class.
  - [x] `brick_registry.dart`: maps a brick name to a widget builder and validates its props.
  - [x] Binding resolver: `bind: product.title` reads from the screen's controller view model.
  - [ ] Action dispatcher: `go`, `back`, `toggle_theme` done; `submit`, `retry`, `set_filter` come with the screens
        that need them (1.4).
- [ ] **Backend:** the shared YAML helper can read rule folders; `settings` reads non-secret defaults from
      `config/app/app.yml`.
- [ ] `make test` and the Flutter test batches are green on the branch before Phase 1 starts.

- [x] **Vertical slice first:** take **Home → Order placed → Your orders** through every layer (tokens, bricks,
      screen YAML, routes, bindings, actions, render test) before converting anything else. If the brick or
      binding design is wrong, it shows up on 3 screens, not 8.

**Done when:** the decisions are recorded, the engines exist with tests, the vertical slice works in light and dark,
and the convention tests run and fail on today's literals. The failing list *is* the Phase 1 and 2 to-do list.

---

## Phase 1: Frontend (theme B, everything in YAML)

### 1.1 Design system and tokens (`ui/theme.yml`)
- [x] Replace the palettes with **theme B**, in light and dark.
  - **Dark:** ground `#0F0B18`, surface `#19132A`, line `#33294D`, strong line `#4A3F66`, text `#F6F2FC`,
    muted `#B4AACB`.
  - **Light:** ground **`#F5F5F5`**, surface `#FFFFFF`, line `#DEDAE5`, strong line `#C9C3D4`, text `#150F20`,
    muted `#57506A`.
  - **Accents:** orange `#FF6A2B`, pink `#FF4D94`, purple `#9D6BFF`, marigold `#FFB627`. Accent ink for text:
    dark `#FF8A57` / `#FF7AAE` / `#BFA0FF` / `#FFC75A`; light `#B83D0B` / `#B4145F` / `#6D28D9`.
  - **On-accent text** is ink (`#0F0B18` / `#150F20`), never white. Orange with white text fails AA.
- [x] **Type:** Space Grotesk (UI) and Space Mono (labels, prices, ids), bundled and subset with
      `tools/subset_fonts.sh`. Inter and Poppins go. Check the web shell size after subsetting (≤ +60 KB).
- [x] **Shape:** radius `sharp` 2, `card` 3–4, no pills.
- [x] **Shadows:** the key-card set (`--sh-ant` layers) for hover and press. On dark it is tinted by the
      card's accent (an orange or pink glow).
- [x] **Motion:** lift −2 / −3 px on hover, scale 0.985 on press, 150 ms. Wire up the unused
      `reduced_motion_factor`.
- [x] Move the contrast rules from `theme_engine.dart` into a `contrast:` block in theme.yml. The test checks
      every pair in both modes.
- [ ] **Theme mode:** the toggle works (home); the default still comes from env THEME_MODE (prod: light); move it to `app/app.yml` (system) and add the toggle to every top bar. `app/app.yml` sets the default (system); the user can switch light and dark from the
      header.
- [ ] Rebuild `/catalog` (dev only) from YAML, so the design system page reads its own text from strings.yml.
- [ ] Update the **CraftStream Design System** artifact to theme B (tokens, type, components), so the canvas,
      the artifact and `theme.yml` agree.
- [ ] **Accessibility tokens:** focus ring (colour, width), minimum touch target 44 px, and semantics label
      templates for cards and icon buttons, all in YAML. Reduced motion turns off lift and scale.

### 1.2 App, routes and navigation
- [ ] `app/app.yml`: app name, initial route, default theme mode, dev-only routes.
- [x] `app/routes.yml`: every route (path, screen file, kind `tab` / `page`, shell, guard `dev_only`) and
      redirects.
- [x] `app/navigation.yml`: the two roles (Buy `01`, Sell `02`) with their accent, entry route and nav items
      (route, label key, icon name). The role rule ("paths under `/studio` are Sell") moves here too.
- [x] **Theme B home** (`/`): the two doors replace the redirect to `/discover`.

### 1.3 Bricks (`ui/bricks.yml` + `lib/shared/bricks/`)
Every reusable widget becomes a brick, with variants, sizes and states in YAML.
- [x] **Basic bricks:** wordmark, door, button (primary / secondary / ghost / danger × sm / md / lg), icon
      button, text field, search field, chip row, sort menu, tag, status badge, price, stepper, notice,
      empty state, load error, skeleton, divider, key-value row, receipt card.
- [x] **Composite bricks:**
  - product card, product grid, listing card, product summary;
  - video player and its overlay (rung pill, controls, buffering);
  - video pick card, upload progress, buy bar, top bar (back + crumb), section header.
- [x] **Poster art:** the colour and shape rules for product posters go in `ui/art.yml`. The painter (geometry)
      stays in Dart.
- [x] `ui/icons.yml`: semantic names (`search`, `back`, `play`, `orders`…) mapped to glyphs. Nothing else
      names an icon.
- [x] `ui/status.yml`: each video and order status gets a label key, accent, dot and hint. This replaces about
      15 Dart switches.
- [ ] `ui/format.yml`: currency symbols and grouping (INR ₹, Indian grouping), the minus sign, bytes and
      duration formats.
- [ ] Skeleton timing (1100 ms) and opacity move into theme motion.

### 1.4 Screens (`screens/*.yml`)
One file per screen. Each lists its data source, its four states (loading, empty, error, data) and its bricks
per size class.
- [x] `home.yml`: wordmark, the two doors, theme toggle.
- [x] `discover.yml`: top bar, title, search, chip row, sort, product grid, load more.
- [x] `product.yml`:
  - stacked or side by side: video, tags, title, artisan row, price, description;
  - buy bar: quantity, then Buy, which goes to checkout.
- [x] `checkout.yml`: product summary, name field, quantity stepper and limit, total, note, Place order.
- [x] **`placed.yml`, the new confirmation screen:** check mark, `03 / DONE`, "Order placed", artisan
      message, receipt card (order number, product, quantity, total, PLACED badge), **See your orders**,
      Keep exploring.
- [x] `orders.yml`: the order list. Each card shows a poster, title, quantity × artisan, total, status, order
      number and date, and opens the receipt. The newest order is highlighted.
- [x] **Orders must survive a restart.** Today `orders_controller.dart` keeps them in memory only and there is
      no endpoint to read an order back, so "check where my order is" breaks once the app is closed.
  - Keep the placed order ids on the device; the storage key and how many to keep go in `orders/orders.yml`.
  - Add `GET /orders/{order_id}` to `models/endpoints.yml` (backend in 2.1). The list and receipt load each
    order from the API, so they show the stored status.
- [x] New copy (orders entry point, theme toggle, `03 / DONE`, receipt labels) goes in `strings.yml`.
- [x] `studio.yml` and `upload.yml`, using the 0.1 Sell mockups.
- [x] Remove the old `features/*/…_screen.dart` layouts. Controllers stay; each feature has a `<feature>_source.dart`
      that exposes its view model and calls. (Left: the dev-only `/catalog` page, rebuilt in 1.1.)

### 1.5 Behaviour still in Dart → YAML
- [ ] `catalog/filters.yml`: sorts become declarative (`field`, `direction`), so adding a sort needs no Dart.
      Re-tapping a tag clears it.
- [ ] `media/player.yml`: master fetch timeout (20 s), HLS MIME type, web `<video>` settings, the
      media-error recovery count. The 50 kbps budget is checked against `ladder.yml`, not a Dart constant.
- [ ] `media/upload.yml`:
  - HTTP status handling (done / continue / retry / reject);
  - extension → MIME map, picker `accept`, metadata timeout (15 s);
  - the tag split, normalise and dedupe rules;
  - the price parsing rule.
- [ ] `app/env_rules.yml`: env policy (https outside dev; no DEV_TOOLS, MOCK_DATA or debug logging in prod),
      the Android dev host.
- [ ] `dev/mock.yml`: mock latency, chunk delay, processing time and the sample product fixtures (they move
      out of `mock_products.dart`).

### 1.6 Responsive check
- [ ] Phone, tablet portrait, tablet landscape and desktop for every screen, in light and dark.
      Progress: screen_render_test draws every screen at 360/390/820/1280 px in both modes; Product, New product /
      Uploading go side by side and Your products shows card columns on wide screens (`width: auto`, `split`,
      `list layout: cards`). Left: a screenshot pass against the canvas at each size (Phase 3). Breakpoints and
      per-class layouts stay in `layout.yml`; screens refer to size classes by name.

**Done when:** the literal lint passes for `lib/features` and `lib/shared/bricks`, every screen is a YAML file,
and the light and dark theme B match the canvas.

---

## Phase 2: Backend (everything in YAML)

### 2.1 App and API
- [ ] `config/app/app.yml`: API title and version, GZip minimum size, log format, required-in-GCP settings
      list. Env vars keep only values that change per environment (project, buckets, origins).
- [ ] `models/endpoints.yml` becomes the single source for routes:
  - the API **mounts routes from it** (handlers by name), instead of hand-written decorators;
  - query params gain constraints (`max_length`, `minimum`);
  - `base_path` is read from it; `/api/v1` disappears from code.
- [ ] `config/api/http.yml`:
  - error code ↔ status map, default messages, the validation and internal error codes;
  - CORS methods, headers and expose list.
  - Add `product_not_ready` to `models/error_response.yml`.
- [x] `GET /orders/{order_id}` (needed by 1.4's Your orders): handler, Firestore read, API test, smoke test step.
      (Code done; the Cloud Run deploy waits for the user's OK.)
- [ ] Keep `/docs` (OpenAPI) correct when routes are mounted from `endpoints.yml`: the handlers keep their typed
      signatures, and the YAML maps path and method to a handler name.

### 2.2 Domain rules
- [x] `config/media/video_lifecycle.yml`:
  - states (from `models/product.yml`), initial state, allowed transitions and the events behind them;
  - Transcoder terminal and success states;
  - the listable and orderable state.
  - This replaces the strings in `product_repo`, `media_service` and `order_rules_engine`.
- [ ] `config/media/storage_layout.yml`: raw path template and regex, HLS prefix, manifest and thumbnail
      names, public base URL, cache-control, Transcoder label key, local sample stream.
- [ ] `config/media/ladder.yml` gains an `encoder:` block:
  - Transcoder: codec key, rate control, container, H.264 profile threshold, sprite grid;
  - local FFmpeg: preset, maxrate and bufsize factors, playlist headroom, HLS version.
- [ ] `config/media/ingest.yml`: ffprobe timeout, error text cap.
- [ ] `config/catalog/listing.yml`: ID length and format, tag normalisation, tag sort, Firestore candidate
      limit (500), cursor strategy, collection names.
- [ ] `config/platform/events.yml`: internal path prefix, Pub/Sub envelope keys, accepted Eventarc event type.

### 2.3 Infra and tools
- [ ] `infra/gcp/resources.yml`: one place for:
  - bucket, topic, subscription and trigger names; enabled APIs;
  - the 14 IAM bindings; lifecycle; CORS (replaces the two `.tmpl` files);
  - Cloud Run sizing; Pub/Sub retry; Firestore indexes.
- [ ] The shell scripts read `resources.yml` through a small Python reader. `config.env` keeps only the 5
      environment values.
- [ ] **Dry run before touching GCP:** the reader prints the gcloud commands. Compare them with the live project
      (`craftstream-qi0tvg` only) and get the user's OK before any IAM, bucket or Cloud Run change is applied.
- [ ] A test cross-checks `resources.yml` against `storage_layout.yml` and the Firestore queries.
- [ ] `tools/tools.yml`: smoke test, throttle proxy and local_hls defaults.

**Done when:** the backend literal lint passes, routes come from `endpoints.yml`, and the inventory's duplicates
are gone.

---

## Phase 3: Make sure everything works

- [ ] `make test` (in batches) and every Flutter test batch are green, including the new convention and
      literal-lint tests.
  - Of today's 24 Flutter test files, the engine, data and format tests should mostly keep passing.
  - `screens_test`, `buyer_flow_test`, `upload_flow_test`, `discover_paging_test` and `product_video_test` are
    rewritten against the YAML screens; their assertions are kept.
- [ ] **Startup cost on the web:** each YAML is a separate HTTP fetch on Chrome. Today that is 6 files and 21 KB;
      V2 adds roughly 20 more.
  - Measure the time to first screen at 45 kbps.
  - If it grows by more than about 2 s, merge all rule YAML into one asset at build time.
- [ ] Screenshot every screen in light and dark across phone, tablet and desktop (golden tests, or a
      Playwright pass on web) and compare them with the canvas.
- [ ] **Local mode:** the full flow with `MOCK_DATA=true` and `CRAFTSTREAM_MODE=local`.
- [ ] **GCP:**
  - redeploy the API, re-run `infra/gcp` from `resources.yml` (no changes expected);
  - run the smoke test;
  - deploy the web app to Firebase Hosting.
- [ ] **Throttled 45 kbps, again:** Chrome (DevTools) and Android (`tools/throttle_proxy.py`).
  - Upload, search, playback starts on 144p without stalls, order placed, the order shows in Your orders.
  - Web shell size measured after the font change.
- [ ] Docs:
  - README screenshots and the architecture section ("how to read the YAML");
  - `ARCHITECTURE.md`; tick this plan.
- [ ] Merge `v2-yaml`. Re-record the demos if V2 is what gets submitted.

## Order of work

```
Phase 0 (investigate, decide, groundwork, vertical slice: home → placed → orders)
  → 1.1 tokens → 1.2 routes → 1.3 bricks → 1.4 screens (home, discover, product, checkout, placed, orders, studio, upload)
  → 1.5 behaviour → 1.6 responsive
  → 2.1 app/API → 2.2 domain → 2.3 infra
  → Phase 3
```

Phases 1 and 2 touch different folders, so the backend can run in parallel with 1.3–1.4 if wanted.
