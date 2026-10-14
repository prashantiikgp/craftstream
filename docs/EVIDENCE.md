# Recording checklist: GCP evidence and the two demos

The three deliverables (see [INTENT.md](INTENT.md)):

1. **Video 1:** architecture walkthrough + live GCP evidence.
2. **Video 2:** Android demo, throttled below 50 kbps: upload → search → watch → order.
3. **Video 3:** Chrome demo, same flow, same throttle.

Project `craftstream-qi0tvg`, region `asia-south1`. Web app: https://craftstream-qi0tvg.web.app.
API: https://craftstream-api-424435123536.asia-south1.run.app.

## Before recording

- Sign in to the Cloud Console with the account that owns the project; open every tab below in advance.
- Have a real process video ready (≤ 15:00, phone-recorded is ideal). Upload one through the deployed app **before**
  recording video 1, so the console shows a fresh Transcoder job, bucket folder and Firestore documents.
- Note that product's id (`/product/<id>` in the app URL); it is the `<id>` in the paths below.
- Chrome: load the web app once at full speed (first load is ~3.2 MB), then set the throttle.

## Video 1: architecture + live GCP evidence (about 5 minutes)

### Console tabs and gcloud equivalents

| What | Console | gcloud |
|---|---|---|
| Cloud Run service, revisions, env vars | https://console.cloud.google.com/run/detail/asia-south1/craftstream-api/revisions?project=craftstream-qi0tvg | `gcloud --project craftstream-qi0tvg run services describe craftstream-api --region asia-south1` |
| Cloud Run logs (structured JSON: `transcode submitted`, `transcode finished`) | https://console.cloud.google.com/run/detail/asia-south1/craftstream-api/logs?project=craftstream-qi0tvg | `gcloud --project craftstream-qi0tvg logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="craftstream-api" AND jsonPayload.message:"transcode"' --freshness=1h --limit=10` |
| Transcoder jobs | https://console.cloud.google.com/transcoder/jobs?project=craftstream-qi0tvg (location `asia-south1`) | `gcloud --project craftstream-qi0tvg transcoder jobs list --location asia-south1` then `… jobs describe <job id> --location asia-south1` (shows the full ladder config, `editList`, `pubsubDestination`) |
| Uploads bucket (private; `raw/<id>/source`; lifecycle deletes raw files) | https://console.cloud.google.com/storage/browser/craftstream-qi0tvg-uploads?project=craftstream-qi0tvg | `gcloud --project craftstream-qi0tvg storage ls gs://craftstream-qi0tvg-uploads/raw/` |
| Media bucket (public; `hls/<id>/manifest.m3u8` + rung playlists + `.m4s`) | https://console.cloud.google.com/storage/browser/craftstream-qi0tvg-media/hls?project=craftstream-qi0tvg | `gcloud --project craftstream-qi0tvg storage ls -l gs://craftstream-qi0tvg-media/hls/<id>/` |
| Firestore `products` and `orders` | https://console.cloud.google.com/firestore/databases/-default-/data/panel/products?project=craftstream-qi0tvg and `…/panel/orders?project=craftstream-qi0tvg` | `gcloud --project craftstream-qi0tvg firestore indexes composite list` (the two indexes behind search) |
| Eventarc trigger `upload-finalized` | https://console.cloud.google.com/eventarc/triggers?project=craftstream-qi0tvg | `gcloud --project craftstream-qi0tvg eventarc triggers describe upload-finalized --location asia-south1` |
| Pub/Sub topic `transcode-done`, push subscription `transcode-done-push` | https://console.cloud.google.com/cloudpubsub/subscription/detail/transcode-done-push?project=craftstream-qi0tvg | `gcloud --project craftstream-qi0tvg pubsub subscriptions describe transcode-done-push` |
| Firebase Hosting | https://console.firebase.google.com/project/craftstream-qi0tvg/hosting | `firebase hosting:channel:list --project craftstream-qi0tvg` |
| Service accounts and IAM | https://console.cloud.google.com/iam-admin/serviceaccounts?project=craftstream-qi0tvg | `gcloud --project craftstream-qi0tvg iam service-accounts list` |

Handy one-liners for the camera:

```bash
curl https://craftstream-api-424435123536.asia-south1.run.app/health            # {"ok":true,"mode":"gcp"}
curl -s https://storage.googleapis.com/craftstream-qi0tvg-media/hls/<id>/manifest.m3u8   # 144p variant listed first
curl -sI https://storage.googleapis.com/craftstream-qi0tvg-media/hls/<id>/manifest.m3u8 | grep -i cache-control  # immutable
backend/.venv/bin/python tools/smoke_test.py https://craftstream-api-424435123536.asia-south1.run.app  # whole flow, live
```

### Suggested order

1. **The idea (30 s).** Artisan uploads a process video; buyer searches, watches under 50 kbps, orders.
   Show the live web app's Discover screen.
2. **Architecture (60 s).** The diagram in `README.md` / `docs/ARCHITECTURE.md` §1. Say the three rules: video bytes
   never pass through the API; the player starts on the lowest rung; everything small on the wire. Mention the one
   architecture rule (YAML → schema → loader → engine) and show `backend/config/media/ladder.yml` next to
   `ladder_engine.py`: the same file drives the Transcoder job and the local FFmpeg ladder.
3. **The upload path, live (90 s).** Cloud Run service page → uploads bucket (`raw/<id>/source`) → Eventarc trigger →
   Cloud Run logs showing `transcode submitted` → Transcoder job (SUCCEEDED; open it and point at the four rungs and
   the `editList` cap) → Pub/Sub subscription → logs showing `transcode finished` → media bucket `hls/<id>/`.
4. **The data (30 s).** Firestore `products` (fields `video_status: ready`, `hls_url`, `keywords`) and `orders`
   (`status: placed`, server-computed `total`).
5. **The 50 kbps proof (60 s).** `curl` the manifest: `BANDWIDTH≈31000` on the first variant plus the 12 kbps audio;
   quote the measured 43.5 kbps average on the wire over a 15-minute upload (worst 6 s segment 45.8 kbps) and
   `docs/ARCHITECTURE.md` §6. Show `tests/integration/test_bitrate_budget.py` in the test list.
6. **Security and ops (30 s).** `/internal/*` accepts only Google-signed OIDC tokens from `craftstream-events@…`;
   uploads bucket private with a lifecycle rule; media bucket public with `immutable` cache headers; no secrets in the
   repo; everything in `infra/gcp/` is idempotent.

### What to point at for each requirement

| # | Point at |
|---|---|
| R1 | Uploads bucket object `raw/<id>/source` (the whole file, uploaded in 8 MiB chunks); `tools/smoke_test.py` output "uploaded … in 8,388,608-byte chunks"; the Transcoder job's `editList` end offset for the 15:00 cap |
| R2 | Firestore product document: `title`, `description`, `price` |
| R3 | `GET /api/v1/products?q=<word>&tag=<tag>` in the browser; the two Firestore composite indexes |
| R4 | Media bucket `hls/<id>/` and the product page playing |
| R5 | Manifest's first variant (256×144, ~31 kbps) + 12 kbps audio; the measured numbers; the rung pill in the app ("144p · …") |
| R6 | Firestore `orders` document with `status: placed`; the "Order placed" screen |
| R7 | The same app at phone width, tablet width and desktop Chrome (video 2 and 3 cover it) |
| R8 | Every console tab above is in `craftstream-qi0tvg`, region `asia-south1` |

## Video 3: Chrome demo, throttled (about 3 minutes)

1. Open https://craftstream-qi0tvg.web.app at full speed and wait for Discover to render. Open DevTools → Network.
2. Switch to **Sell**, open **New listing**. Fill in title, description, price, tags; pick a video. Say that the app
   checked the duration against `/upload-policy` before uploading.
3. Watch the chunked upload (DevTools shows `PUT` requests with `Content-Range` to `storage.googleapis.com`). Optional:
   with `DEV_TOOLS` on, press "Simulate a dropped connection" to show the resume; on the hosted (prod) build, toggle
   DevTools "Offline" for a few seconds instead and watch it resume from the received offset.
4. Wait for **processing → live** (the app polls `GET /products/<id>`; a 15-minute video takes a few minutes).
5. **Set the throttle now:** DevTools → Network → throttling dropdown → *Custom* → add a profile with
   download **45 kbps**, upload 45 kbps, latency **300 ms**; select it. Set it only after the app has loaded.
6. Switch to **Buy**. Search for a keyword from the title and tap a tag chip; the new product appears.
7. Open the product and press play. Point at the rung pill ("144p …"): the player started on the lowest rung and
   keeps playing without stalling. Let it run for a while so the viewer sees it.
8. **Buy** → name + quantity → **Place order** → "Order placed". Open **Orders** to show it stored.
9. Optionally narrow the window to phone width and widen it to desktop to show the responsive layouts.

## Video 2: Android demo, throttled (about 3 minutes)

Same flow as video 3, on the Android emulator (phone, then a tablet AVD for a few seconds).

1. Build and install: `make apk ENV=prod` (output `frontend/build/app/outputs/flutter-apk/app-release.apk`), then
   `adb install -r <apk>`.
2. Start the throttle and the emulator. The emulator's own `-netspeed` shaper is unusable at these rates (at
   45 kbps it delivered about 2 kbps and the catalog request timed out), so all of the emulator's traffic goes through
   a capped proxy instead. It prints the measured kbps every 10 s, which is worth keeping on screen:
   ```bash
   python3 tools/throttle_proxy.py --kbps 45 --rtt-ms 300          # WSL or any terminal; listens on 127.0.0.1:8045
   emulator -avd <name> -http-proxy http://127.0.0.1:8045 -no-snapshot
   ```
   Before recording, keep Google's background downloads (voice data, text-classifier models, Play services sync)
   off the 45 kbps link, the way a phone on a slow metered connection would. Let the image finish its first-boot
   downloads at full speed, then turn on Data Saver with the app exempt:
   ```bash
   adb shell cmd netpolicy set metered-network '"AndroidWifi"' true
   adb shell cmd netpolicy set restrict-background true
   adb shell cmd netpolicy add restrict-background-whitelist $(adb shell pm list packages -U | grep craftstream | sed 's/.*uid://')
   adb shell pm disable-user --user 0 com.google.android.tts
   ```
   Restart the proxy afterwards (it drops any download already running). With `-v` it prints the top connections
   every 10 s, so you can confirm the link is idle before you start.
   The 20 s test clip uploads in about 3.5 minutes at 45 kbps, so a short clip keeps the video short.
3. Sell → New listing → pick a video from the device → upload (toggle airplane mode on and off mid-upload to show the
   resume) → wait for live.
4. Buy → search + tag → product → play (rung pill shows 144p) → Buy → Order placed → Orders.
5. Repeat the product screen on a tablet AVD in portrait and landscape to show the layouts (R7).
