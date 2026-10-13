# Environments

One file per environment, compiled into the app with `--dart-define-from-file=env/<name>.json`
(`make web ENV=dev`, `make apk ENV=prod`). Read and validated once at startup by `lib/core/env.dart`.

**Everything here ends up inside the shipped app and can be read by anyone who downloads it.**
So these files hold public settings only. API keys, tokens, passwords and service-account data never
go in the app; they stay on the backend (Cloud Run env vars / Secret Manager).

| Key | Values | Rule enforced at startup |
|---|---|---|
| `APP_ENV` | `dev` · `staging` · `prod` | required in release builds |
| `API_HOST` | base URL of the API | `https://` outside dev; no user:password, path, query or fragment |
| `THEME_PALETTE` | a palette name from `assets/config/ui/theme.yml` | must exist in theme.yml |
| `THEME_MODE` | `light` · `dark` · `system` | |
| `DEV_TOOLS` | `true` · `false` | must be `false` in prod (palette switcher, debug overlays) |
| `LOG_LEVEL` | `debug` · `info` · `warn` · `error` | `debug` not allowed in prod |

A test (`test/core/env_files_test.dart`) fails if any env file has an unknown key, a key that looks like a secret
(`*KEY*`, `*SECRET*`, `*TOKEN*`, `*PASSWORD*`, `*CREDENTIAL*`) or breaks the rules above.
The staging and prod `API_HOST` values are placeholders until the Cloud Run URL exists (B4).
