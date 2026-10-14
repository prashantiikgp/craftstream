# Frontend: Flutter (Android phone, Android tablet, Chrome)

Read with the root `CLAUDE.md`. Full plan: `docs/FRONTEND_PLAN.md`.

## Layers

| Layer | Folder | May | Must not |
|---|---|---|---|
| Rules | `assets/config/<domain>/<xyz>.yml` | hold theme, layout, strings, filters, player and upload-retry settings | hold API URLs or secrets |
| Schemas | `lib/schemas/<domain>/<xyz>_schema.dart` | define immutable classes with `fromJson` that reject unknown keys | contain logic |
| Loaders | `lib/domain/<domain>/<xyz>_loader.dart` | call `core/yaml_loader.dart`, load once at startup | do anything else |
| Engines | `lib/domain/<domain>/<xyz>_engine.dart` | pure Dart over loaded rules | import Flutter widgets, HTTP or repositories |
| Data | `lib/data/repositories/`, `lib/data/upload/`, `lib/data/mock/` | call the generated API client and GCS (or the mock) | contain UI or business rules |
| Generated | `lib/data/generated/` | be imported by repositories | be edited by hand |
| Features | `lib/features/<feature>/` | screen + widgets + controller (Riverpod) | read YAML or call HTTP directly |
| Shared | `lib/shared/widgets/` | widgets used by 2+ features | hold feature logic |

**Flow:** `screen → controller → engine (rules) or repository (data)`.

**Nothing hard-coded in screens:**
- text comes from `strings_engine`: `context.s('group.key', {'name': value})`, keys as string literals
  (`strings_engine_test` fails on a missing or unused key);
- colours and spacing come from `theme_engine`;
- breakpoints and columns come from `layout_engine`;
- player settings come from `player_engine`.

Upload limits are **not** frontend YAML: read them from `GET /api/v1/upload-policy`. Form limits mirror
`models/*.yml` as constants in the controllers; `test/features/model_limits_test.dart` keeps them in step.

**Real or mock data:** `lib/data/providers.dart` is the only place that chooses. `MOCK_DATA=true` (dev) uses
`MockStore` (sample products, the API's search rules, a simulated resumable upload); otherwise the generated
API client. Screens and controllers only see the repository interfaces.

## Screens are YAML (V2, docs/YAML_PLAN.md)

| File | Says |
|---|---|
| `assets/config/app/routes.yml` | every route; each shows a screen YAML (`screen:`) or, until migrated, a v1 Dart screen (`legacy:`) |
| `assets/config/app/navigation.yml` | the Buy (01, orange) and Sell (02, pink) roles |
| `assets/config/ui/screens/<name>.yml` | one screen: `data` source, `width`, `fill`, `backdrop`, and `top` / `body` / `bottom` / `empty` / `error` bricks |
| `assets/config/ui/bricks.yml` | the brick catalogue: each brick's props (what a screen may set) and style (its look, in tokens) |
| `assets/config/ui/icons.yml` | line icons as SVG path data. Never use `Icons.*` |
| `assets/config/ui/status.yml` | label, tone and hint for each video and order status. Never compare status strings |
| `assets/config/ui/art.yml` | backdrop shapes, door art, the poster generator |

- **How it runs:**
  - `core/router.dart` builds GoRouter from routes.yml.
  - `shared/screens/screen_host.dart` draws a screen.
  - `shared/bricks/bricks.dart` has one builder per brick.
  - `shared/screens/sources.dart` lists the data sources a screen's `data:` can name.
- **Bindings:**
  - `order.total` reads the screen's data, `item.id` the current list entry, `params.order_id` the route.
  - Data keys are the `models/*.yml` field names (`toJson()`).
- **Actions:** `{go: /placed/{item.id}}`, `{back: true}`, `{toggle_theme: true}`. A `go:` target must match routes.yml.
- **Startup checks every screen:** an unknown brick, prop, strings key, icon, role, colour, text style or route fails
  with the file and position. `test/features/screen_render_test.dart` then draws every screen at phone, tablet and
  desktop sizes, in light and dark.
- **New brick:**
  1. Add it to bricks.yml (props + style).
  2. Add a builder in `bricks.dart` that reads only its node and `BrickStyle`.
  3. The render test fails until both exist.
- **New screen:**
  1. Write `ui/screens/<name>.yml`.
  2. Add a route.
  3. Add a source if it shows data.

## Design system

- **Theme B** ("two doors"; canvas "CraftStream new look"): sharp corners, Space Grotesk and Space Mono, accents
  orange, pink, purple and marigold. Light mode uses a `#F5F5F5` ground, dark mode `#0F0B18`.
- Tokens live in `assets/config/ui/theme.yml`:
  - `colors` (ground, surface, line, text…, per mode);
  - `accents` (fill / on_fill / ink / wash / line, per mode) and `tones` (success → marigold …);
  - `styles` (type, by name), `spacing`, `radius` (none / sharp / card), `shadows`, `motion`, `focus`;
  - `contrast` (the WCAG pairs `theme_engine_test` checks in both modes).
- In code:
  - `context.tokens` gives colours, space, radius and shadows;
  - `t.tone('danger')` gives a meaning's colours;
  - `t.lift(accentFill)` gives the key-card hover shadow;
  - `context.type.named('eyebrow')` gives a text style. Styles with `upper: true` are shown in capitals.
- **v1 names** (`brand`, `brand_ink`, `card`, `hair`, `sub` …) still work through theme.yml's temporary `legacy:` block
  until the last v1 screen is replaced. New bricks use the theme B names.
- `/catalog` (DEV_TOOLS only) shows every token and switches light/dark live. Users switch with the theme toggle.
- Fonts are bundled and subset (`tools/subset_fonts.sh`, ~137 KB). Never add `google_fonts` runtime fetching.

## Environments (security)

- `env/dev.json`, `env/staging.json`, `env/prod.json` → `--dart-define-from-file`; `make web ENV=dev`, `make apk ENV=prod`.
- **Everything in an env file ships inside the app.** Public settings only; secrets stay on the backend.
- `core/env.dart` validates at startup (https outside dev, no credentials in API_HOST, no DEV_TOOLS or debug logs in
  prod, APP_ENV required in release). `test/core/env_files_test.dart` rejects unknown or secret-looking keys.
- New key: add it to `AppEnv`, all three env files, `env/README.md` and the test's allow-list.

## Recipe: add a rule file

1. Create `assets/config/<domain>/<xyz>.yml` and list it in `pubspec.yaml` assets.
2. Write `lib/schemas/<domain>/<xyz>_schema.dart`: `@JsonSerializable()` classes, all fields `final` (`build.yaml` turns on
   unknown-key rejection and snake_case keys for everything in `lib/schemas/`), then `make flutter-gen`.
3. Write `lib/domain/<domain>/<xyz>_loader.dart`, which calls `loadYamlAsset`, and load it in `core/config.dart::loadAppConfig`.
4. Write `lib/domain/<domain>/<xyz>_engine.dart`. It takes the schema object in its constructor.
5. Add `test/domain/<domain>/<xyz>_engine_test.dart`.

If any YAML fails to load, the app shows an error screen at startup. It never runs with half the config.

## Recipe: add a screen

1. Create `lib/features/<feature>/` with `<feature>_screen.dart`, `<feature>_controller.dart` and `widgets/`.
2. Add a route in `core/router.dart`.
3. Put all text in `strings.yml`; build the layout from `layout_engine` size classes (phone / tablet / wide).
4. Every async screen handles four states: loading, empty, error and data.

## Low-bandwidth rules (< 50 kbps)

- **The player starts on the lowest rung.** On web, set hls.js `startLevel: 0` and use a low starting bandwidth estimate. On Android, cap the initial bitrate. All values come from `player.yml`.
- No autoplay in grids. Thumbnails are small posters; the video loads only on the product screen.
- Show a poster and a buffering indicator while the first segment loads.
- Keep list payloads small and debounce search input.

## Upload rules

- Check the video duration on the device against `/upload-policy` before uploading.
- `resumable_uploader.dart` sends chunks (size from the `UploadTicket`) to the GCS resumable URL. After a drop, it asks GCS for the received offset and resumes from there.
- On web, use `file_picker` with `withReadStream: true`. Never load the whole file into memory.
- After the upload, poll the product until `video_status` is `ready` or `failed`.

## Running from WSL

- Use the Linux Flutter SDK (`~/development/flutter`), never the Windows one under `/mnt/d`.
- **Web:** `make web ENV=dev` (web-server on :8080), then open it in Windows Chrome.
- **Android emulator:** use the same `env/dev.json`; `AppEnv.apiHostFor` maps `localhost` to `10.0.2.2` in dev.
  WSL has no `/dev/kvm`, so the emulator runs on Windows: `/mnt/c/Users/<you>/AppData/Local/Android/Sdk/emulator/emulator.exe`
  and `platform-tools/adb.exe` (the Windows adb, not a Linux one). Gotchas on this 8 GB machine: launch headless with
  `-no-window -no-snapshot -no-audio -memory 1536`; a Linux `adb` server also bound to :5037 (mirrored networking) blocks
  the Windows one, so kill it first; the Play Store image shows "Allow USB debugging?", which the emulator console can
  answer without adb (`adb.exe emu screenrecord screenshot <dir>` to look, `adb.exe emu event mouse x y 0 1` / `... 0 0` to tap).
- Schemas changed? `make flutter-gen` (json_serializable). Tests: `make flutter-test`.
- **Throttled demo:** load the app first, then switch on the 45 kbps throttle. The hosted web shell is about 3.2 MB compressed (CanvasKit).
- **Throttled Android:** not `-netspeed` (it runs far below its setting). Run `tools/throttle_proxy.py --kbps 45` and start the emulator with `-http-proxy http://127.0.0.1:8045`.

## Style

`flutter_lints`, `const` constructors wherever possible, and no `print` (use a logger). Tests mirror `lib/` under `test/`.
