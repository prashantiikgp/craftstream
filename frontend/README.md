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
