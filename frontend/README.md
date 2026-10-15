# CraftStream app (Flutter)

Android phone, Android tablet and Chrome from one codebase. Rules for working here: [CLAUDE.md](CLAUDE.md).
Plan: [docs/FRONTEND_PLAN.md](../docs/FRONTEND_PLAN.md).

```bash
make web ENV=dev          # from the repo root: web server on :8080 against the local API
make apk ENV=prod         # release APK against the deployed API
make flutter-test         # analyze + tests
make flutter-gen          # after changing anything in lib/schemas/
```

- Screens, bricks, routes and design tokens: `assets/config/` (see CLAUDE.md, "Screens are YAML")
- Environments: `env/*.json` (public settings only, see `env/README.md`)

## App icons

The Android launcher icons (`android/app/src/main/res/`) and the web favicon and icons (`web/`) are plain files. The
in-app mark is the three stripes drawn by the `wordmark` and `top_bar` bricks from theme tokens.
