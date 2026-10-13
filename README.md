# CraftStream

An artisan marketplace where each product comes with a "how it was made" video that **plays smoothly on connections under 50 kbps**. Built for the DevDolphins technical assignment.

- **Frontend:** Flutter (one codebase for Android phone, Android tablet, and Chrome)
- **Backend:** Python FastAPI on Cloud Run
- **Video:** Cloud Storage resumable uploads → Transcoder API → adaptive HLS (fMP4)
- **Data:** Firestore

## How the repo is organized

```
models/          shared data models + API endpoints (YAML) → `make gen` → code for both sides
backend/         FastAPI service (Cloud Run)
  config/        rule files (YAML), e.g. media/ladder.yml: the bitrate ladder (144p @ 40 kbps → 720p)
  app/           schemas/ · domain/ (loaders + engines) · db/ · infra/gcp/ · generated/
  tests/         unit, API and contract tests
frontend/        Flutter app (Android phone, Android tablet, Chrome)
infra/gcp/       gcloud scripts (coming in phase B4)
tools/           codegen.py, local_hls.py (FFmpeg ladder for local testing), setup_flutter.sh
docs/            intent, plans, architecture
```

**Pattern:** every rule file `config/<domain>/<xyz>.yml` has a schema (`schemas/<domain>/<xyz>_schema`), a loader and an engine (`domain/<domain>/<xyz>_loader`, `<xyz>_engine`).

**Workflow:** edit a YAML file in `models/` → `make gen` → both the backend and the app pick up the change. Never edit files in a `generated/` folder; VS Code marks them read-only.

## First-time setup (in WSL)

```bash
cd ~/projects/craftstream
make setup          # backend/.venv + dependencies
make test           # API flow, contract vs. models/endpoints.yml, 50 kbps budget
make api            # API at http://localhost:8000/docs (in-memory, no GCP needed)
make flutter-init   # once Flutter is installed: creates android/ and web/, adds hls.js
make web            # app on http://localhost:8080 against the local API
code .              # open in VS Code
```

## The 50 kbps rung (measured)

`make hls SRC=your_video.mp4` builds the ladder locally with FFmpeg, using the same settings as the GCP Transcoder job, and reports what a player downloads per rung. The 144p rung measures **42.8 kbps on the wire** (playlists + init + segments + HTTP headers), even on a deliberately grainy worst-case clip; no 6-second segment exceeds 43 kbps. Details: [docs/ARCHITECTURE.md §6](docs/ARCHITECTURE.md).

| Container | 144p rung on the wire |
|---|---|
| MPEG-TS segments | 56.7 kbps ❌ |
| **fMP4 segments** | **42.8 kbps ✅** |

At these bitrates the TS container alone added about 14 kbps of overhead, so the project uses fMP4. `make test` re-checks the budget on every run.

## Status

- [x] YAML data models + code generator
- [x] Repo restructured into models/ · backend/ · frontend/ with the YAML → schema → loader → engine pattern
- [x] API contract v0.2: create listing, paged search/filter, tags, upload policy, order, one error shape
- [x] Local mode: fake resumable upload target (same protocol as GCS)
- [x] Transcoder API job config built from the ladder
- [x] Flutter: search screen + HLS player
- [ ] GCP project, buckets, Firestore, Cloud Run deploy
- [ ] Pub/Sub callback when transcoding finishes
- [ ] Flutter: artisan upload screen (resumable), order screen
- [ ] Throttled demo recordings (Chrome DevTools + Android emulator)
