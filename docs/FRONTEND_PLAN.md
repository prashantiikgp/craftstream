# CraftStream: Frontend Plan

Part of the [master plan](PLAN.md). Backend: [BACKEND_PLAN.md](BACKEND_PLAN.md).

**Stack:** Flutter (one codebase → Android phone, Android tablet, Chrome web) · `video_player` + hls.js on web · Riverpod (state, proposed) · go_router

---

## 1. What the frontend is responsible for

| Journey | Screens |
|---|---|
| **Artisan** uploads a process video + product details | Upload: form → pick video → duration check → resumable upload with progress → "processing" → "live" |
| **Buyer** searches and discovers | Catalog: search box + tag chips + product grid (thumbnails only, no autoplay) |
| **Buyer** watches the process video | Product: HLS player that **starts on the lowest quality** + details + Buy button |
| **Buyer** orders | Checkout: name + quantity → "Order placed" (the flow ends there) |

There is no login (not in scope): a simple **Buyer / Artisan** switch on the home screen, and the artisan types their name in the upload form.

---

## 2. Folder structure

```
frontend/
├── pubspec.yaml  CLAUDE.md
├── assets/config/                       ① RULES (YAML), one folder per domain
│   ├── ui/theme.yml  ui/layout.yml  ui/strings.yml
│   ├── player/player.yml
│   └── catalog/filters.yml
├── lib/
│   ├── main.dart                        load all config at startup → bad YAML shows an error screen
│   ├── app.dart                         MaterialApp + theme + router
│   ├── core/                            env.dart (API_HOST), router.dart, errors.dart, yaml_loader.dart
│   ├── schemas/                         ② SCHEMAS, mirrors assets/config/
│   │   ├── ui/theme_schema.dart  layout_schema.dart  strings_schema.dart
│   │   ├── player/player_schema.dart
│   │   └── catalog/filters_schema.dart
│   ├── domain/                          ③ LOADERS + ENGINES
│   │   ├── ui/       theme_loader/engine · layout_loader/engine · strings_loader/engine
│   │   ├── player/   player_loader.dart  player_engine.dart
│   │   └── catalog/  filters_loader.dart  filters_engine.dart
│   ├── data/                            ④ TALKING TO THE BACKEND
│   │   ├── generated/                   models.dart + api_client.dart from /models (never edit by hand)
│   │   ├── repositories/                product_repository.dart, order_repository.dart
│   │   └── upload/resumable_uploader.dart
│   ├── features/                        ⑤ SCREENS, one folder each: screen + widgets + controller
│   │   ├── home/  catalog/  product/  checkout/  upload/
│   └── shared/widgets/                  only once 2+ features use a widget
├── web/  android/                       platform shells (from `flutter create`)
└── test/                                mirrors lib/
```

**Rules:**
- **Screens never read YAML or call HTTP directly.** Screens → controller → engine (rules) or repository (data).
- **Screens never hard-code text, colours or breakpoints.** Those come from `strings_engine`, `theme_engine` and `layout_engine`.

---

## 3. Rule files: YAML → schema → loader → engine

| YAML | Engine's job | Example rules inside |
|---|---|---|
| `ui/theme.yml` | `theme_engine` → Flutter `ThemeData` | colours, type scale, radius, spacing |
| `ui/layout.yml` | `layout_engine`: is this a phone or a tablet? how many grid columns? player beside or above the details? | breakpoint 600 dp, columns per size class, tablet-landscape split |
| `ui/strings.yml` | `strings_engine`: every piece of UI text | labels, empty/error states, button text |
| `player/player.yml` | `player_engine`: how playback starts and adapts | start on lowest rung, max initial bitrate, buffer goal, when to switch to the low-band manifest |
| `catalog/filters.yml` | `filters_engine`: which tag chips and sort options show | featured tags, chip order, default sort |

Upload limits (15 min, file types) are **not** a frontend YAML. The app reads them from `GET /api/v1/upload-policy`, so the rule exists only in the backend's `upload_policy.yml`.

---

## 4. Two hard parts

### A. Smooth playback under 50 kbps
- The backend ladder has a 144p rung of ~40 kbps. The player still has to **pick it first**. By default, ExoPlayer (Android) and hls.js (web) guess a high bandwidth, fetch a large segment and stall.
- `player_engine` sets the start: hls.js `startLevel: 0` plus a low starting bandwidth estimate on web, and a capped initial bitrate on Android.
- If the stock `video_player` plugin won't expose these settings: use a small custom hls.js bridge on web, or request a "low-band" master manifest that lists only the bottom rungs.
- Show a tiny poster image while the first segment loads, plus a visible buffering indicator.

### B. Uploading a 15-min, any-size video
- Check the duration on the device before uploading, against `/upload-policy`.
- `resumable_uploader.dart` streams the file in chunks (size from the `UploadTicket`) to the GCS resumable URL.
- If the network drops, it asks GCS how many bytes arrived and continues from there.
- On web, pick the file with `withReadStream: true` so a 2 GB file is never loaded into memory.
- After the upload, poll the product until `video_status` is `ready`.

---

## 5. Phases and tasks

### F1: Setup
- [x] Install the Linux Flutter SDK in WSL (the current PATH points to the Windows SDK, which breaks with `bash\r`); JDK 17 + Android SDK
- [x] `flutter create --platforms=android,web` inside `frontend/`; add packages: riverpod, go_router, yaml, json_serializable, video_player, file_picker, http
- [x] Folder skeleton + `core/yaml_loader.dart` + config bootstrap + error screen for bad YAML
- [x] Environments: `env/{dev,staging,prod}.json` validated by `core/env.dart` (https outside dev, no dev tools/debug logs in prod, no secrets: test-enforced)
- [x] Fonts bundled + subset (Poppins/Inter, Latin + ₹, ~170 KB)
- [ ] Done when `make web` opens the app in Chrome and `make apk` builds

### F2: Rule files (the pattern, ×5)
- [x] `theme` (design tokens, 3 palettes, WCAG-tested) and `layout` (size classes, grid): YAML + `_schema` + `_loader` + `_engine` + tests
- [x] Design system components (`lib/shared/widgets/`) + `/catalog` live gallery with palette and light/dark switcher
- [ ] For `strings`, `player` and `filters`: YAML + `_schema` + `_loader` + `_engine` + tests
- [ ] Done when the app shell (home with Buyer/Artisan switch) is fully driven by YAML

### F3: Data layer
- [ ] Wire the generated API client + `env.dart` (`API_HOST` via `--dart-define`)
- [ ] `product_repository`, `order_repository`; loading/empty/error states
- [ ] Done when the app lists products from the local backend (in-memory mode)

### F4: Features
- [ ] **catalog**: search box (debounced) + tag chips + responsive grid
- [ ] **product**: player + details + Buy
- [ ] **checkout**: name + quantity → "Order placed"
- [ ] **upload**: form → picker → duration check → resumable upload with progress → poll until ready
- [ ] Done when the full artisan → buyer → order flow works on Chrome and the Android emulator against the local backend

### F5: Low-bandwidth player
- [ ] `player_engine` start-low settings on web (hls.js) and Android (ExoPlayer)
- [ ] Test under a 45 kbps throttle: Chrome DevTools custom profile; Android emulator `-netspeed` / GPRS
- [ ] Fallback low-band manifest if needed
- [ ] Done when a video plays without stalling under throttle on both platforms

### F6: Builds + demo
- [ ] Point at the Cloud Run URL; web build → Firebase Hosting; release APK
- [ ] Check layouts on phone, tablet (portrait + landscape) and desktop Chrome
- [ ] Record video 1 (Android) and video 2 (Chrome): upload → search → throttled playback → order

---

## 6. Definition of done (frontend)
- One codebase runs on an Android phone, an Android tablet and Chrome
- An artisan can upload a 15-min video that survives a network drop mid-upload
- A buyer searches by keyword and tag, watches smoothly under 50 kbps, and places an order
- No hard-coded text, colours, breakpoints or player settings in the screens; all of it is in YAML
