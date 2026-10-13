# CraftStream app (Flutter)

Android phone, Android tablet and Chrome from one codebase. Rules for working here: [CLAUDE.md](CLAUDE.md).
Plan: [docs/FRONTEND_PLAN.md](../docs/FRONTEND_PLAN.md).

```bash
make web ENV=dev          # from the repo root: web server on :8080 against the local API
make apk ENV=prod         # release APK against the deployed API
make flutter-test         # analyze + tests
make flutter-gen          # after changing anything in lib/schemas/
```

- Design tokens: `assets/config/ui/theme.yml` · live gallery at `/#/catalog` (dev and staging only)
- Environments: `env/*.json` (public settings only, see `env/README.md`)

## Brand artwork

The mark is a thrown clay vessel with a play button cut out of its belly, standing on a potter's wheel: craft plus video.
It is defined once, as path data in `lib/shared/brand/brand_geometry.dart`, and drawn everywhere from there:

- **In the app:** `BrandLockup`, `BrandMark`, `SpotIllustration` (empty search, processing, order placed, slow network) and
  `ProductPosterPlaceholder` (a 16:9 texture per craft) in `lib/shared/brand/`. They are painted in code from the active palette,
  so they follow palette and light/dark and download nothing.
- **Files:** `assets/brand/*.svg` (sources), the Android adaptive icon (`res/drawable/ic_launcher_*.xml`,
  `res/mipmap-anydpi-v26/`), the legacy launcher PNGs and the web favicon, icons and maskable icons.

The files are generated and must not be edited by hand. After changing the geometry or the saffron palette, regenerate them:

```bash
~/development/flutter/bin/flutter test test/shared/brand/brand_assets_test.dart --dart-define=WRITE_BRAND=true
```

This also writes previews to `../.playwright-mcp/brand/` (gitignored). A normal `flutter test` fails if any file is missing or stale.
