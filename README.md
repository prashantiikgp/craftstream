# CraftStream

An artisan marketplace where each product comes with a "how it was made" video that **plays smoothly on connections under 50 kbps**. Built for the DevDolphins technical assignment.

- **Frontend:** Flutter (one codebase for Android phone, Android tablet, and Chrome)
- **Backend:** Python FastAPI on Cloud Run
- **Video:** Cloud Storage resumable uploads → Transcoder API → adaptive HLS (fMP4)
- **Data:** Firestore

## How the repo is organized

```
specs/                 ← the source of truth (human-readable YAML)
  models/              product.yaml, order.yaml: fields and validation rules
  api/endpoints.yaml   the API contract
  media/ladder.yaml    the bitrate ladder (144p @ 40 kbps up to 720p)
tools/codegen.py       YAML → Pydantic models, Dart models, Dart API client
backend/               FastAPI app (+ tests, Dockerfile for Cloud Run)
transcoder/            ladder → Transcoder API job; local FFmpeg version for testing
app/                   Flutter app
```

**Workflow:** edit a YAML file → `make gen` → both the backend and the app pick up the change. Never edit files in a `generated/` folder; VS Code marks them read-only.

## First-time setup (in WSL)

```bash
cd ~/projects/craftstream
make setup          # Python venv + dependencies
make test           # 5 tests: API flow, contract vs. YAML, 50 kbps budget
make api            # API at http://localhost:8000/docs (in-memory, no GCP needed)
make flutter-init   # once Flutter is installed: creates android/ and web/, adds hls.js
make web            # app in Chrome against the local API
code .              # open in VS Code
```

## The 50 kbps rung (measured)

`make hls SRC=your_video.mp4` builds the ladder locally with FFmpeg. On a 60-second 1080p test pattern (harder to compress than real footage), the 144p rung came out to:

| Container | On-the-wire average |
|---|---|
| MPEG-TS segments | 56.7 kbps ❌ |
| **fMP4 segments** | **42.0 kbps ✅** |

At these bitrates, the TS container alone added about 14 kbps of overhead, so the project uses fMP4.

## Status

- [x] YAML specs + code generator
- [x] API: create listing, search/filter, product detail, upload-complete, order
- [x] Transcoder API job config built from the ladder
- [x] Flutter: search screen + HLS player
- [ ] GCP project, buckets, Firestore, Cloud Run deploy
- [ ] Pub/Sub callback when transcoding finishes
- [ ] Flutter: artisan upload screen (resumable), order screen
- [ ] Throttled demo recordings (Chrome DevTools + Android emulator)
