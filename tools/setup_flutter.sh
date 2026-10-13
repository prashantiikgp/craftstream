#!/usr/bin/env bash
# One-time Flutter setup: creates android/ and web/ platform folders without touching lib/,
# then checks web/index.html still loads the bundled hls.js so Chrome can play HLS.
set -euo pipefail
cd "$(dirname "$0")/../frontend"
flutter create --platforms=android,web --project-name craftstream --org com.craftstream .
flutter pub get
# hls.js is bundled in web/vendor/ (loaded by web/index.html), never fetched from a CDN at runtime.
grep -q "vendor/hls.light.min.js" web/index.html || echo "warning: web/index.html does not load vendor/hls.light.min.js"
echo "Flutter app ready. Try: make web"
