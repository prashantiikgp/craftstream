# Frontend: Flutter (Android phone, Android tablet, Chrome)

Read with the root `CLAUDE.md`. Full plan: `docs/FRONTEND_PLAN.md`.

## Layers

| Layer | Folder | May | Must not |
|---|---|---|---|
| Rules | `assets/config/<domain>/<xyz>.yml` | hold theme, layout, strings, player and filter settings | hold API URLs or secrets |
| Schemas | `lib/schemas/<domain>/<xyz>_schema.dart` | define immutable classes with `fromJson` that reject unknown keys | contain logic |
| Loaders | `lib/domain/<domain>/<xyz>_loader.dart` | call `core/yaml_loader.dart`, load once at startup | do anything else |
| Engines | `lib/domain/<domain>/<xyz>_engine.dart` | pure Dart over loaded rules | import Flutter widgets, HTTP or repositories |
| Data | `lib/data/repositories/`, `lib/data/upload/` | call the generated API client and GCS | contain UI or business rules |
| Generated | `lib/data/generated/` | be imported by repositories | be edited by hand |
| Features | `lib/features/<feature>/` | screen + widgets + controller (Riverpod) | read YAML or call HTTP directly |
| Shared | `lib/shared/widgets/` | widgets used by 2+ features | hold feature logic |

**Flow:** `screen → controller → engine (rules) or repository (data)`.

**Nothing hard-coded in screens:**
- text comes from `strings_engine`;
- colours and spacing come from `theme_engine`;
- breakpoints and columns come from `layout_engine`;
- player settings come from `player_engine`.

Upload limits are **not** frontend YAML: read them from `GET /api/v1/upload-policy`.

## Recipe: add a rule file

1. Create `assets/config/<domain>/<xyz>.yml` and list it in `pubspec.yaml` assets.
2. Write `lib/schemas/<domain>/<xyz>_schema.dart`: `@JsonSerializable(disallowUnrecognizedKeys: true)`, all fields `final`.
3. Write `lib/domain/<domain>/<xyz>_loader.dart`, which calls the shared YAML helper and is registered in the startup bootstrap.
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
- **Web:** `flutter run -d web-server --web-port 8080`, then open it in Windows Chrome.
- **Android emulator:** the API host is `http://10.0.2.2:8000`.
- Pass the API host with `--dart-define=API_HOST=...`; it is read in `core/env.dart`.
- **Throttled demo:** load the app first, then switch on the 45 kbps throttle. The web shell is about 2 MB.

## Style

`flutter_lints`, `const` constructors wherever possible, and no `print` (use a logger). Tests mirror `lib/` under `test/`.
