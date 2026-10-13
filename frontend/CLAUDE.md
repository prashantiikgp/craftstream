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

## Design system

- Tokens: `assets/config/ui/theme.yml` (palettes with brand + secondary ramps, surfaces, status quartets, type scale,
  spacing, radius, elevation, motion). Built on the Fluno client system (same names, same orange `#FE5722`).
- In widgets: `final t = context.tokens;` for colours/space/radius/shadows, `context.type.h1` etc. for text.
  Components live in `lib/shared/widgets/` (import `shared/widgets/ds.dart`): `AppButton`, `AppCard`, `StatusBadge`,
  `TagChip`, `AppTextField`, `Notice`, `PriceText` (₹1,20,000), `SectionHeader`, `EmptyState`, `Skeleton`.
- Colour names: `brand` = fills only; `brand_ink` = orange **text**; `brand_l/ll` = tints; `on_brand` = text on a brand
  fill. Status colours come as `fill / border / ink / wash`. Never use a raw `Color(0x…)` in a screen.
- New palette: add it under `palettes:` in theme.yml. `theme_engine_test` fails if any text pair drops below WCAG AA.
- `/catalog` (DEV_TOOLS only) shows every token and component and switches palette + light/dark live.
- Fonts are bundled and subset (`tools/subset_fonts.sh`, ~170 KB). Never add `google_fonts` runtime fetching.

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
- Schemas changed? `make flutter-gen` (json_serializable). Tests: `make flutter-test`.
- **Throttled demo:** load the app first, then switch on the 45 kbps throttle. The web shell is about 2 MB.

## Style

`flutter_lints`, `const` constructors wherever possible, and no `print` (use a logger). Tests mirror `lib/` under `test/`.
