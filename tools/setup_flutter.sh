#!/usr/bin/env bash
# One-time Flutter setup: creates android/ and web/ platform folders without touching lib/,
# then adds hls.js to web/index.html so Chrome can play HLS.
set -euo pipefail
cd "$(dirname "$0")/../frontend"
flutter create --platforms=android,web --project-name craftstream --org com.craftstream .
flutter pub get
if ! grep -q "hls.js" web/index.html; then
  sed -i 's|</head>|  <script src="https://cdn.jsdelivr.net/npm/hls.js@1.5.17/dist/hls.min.js"></script>\n</head>|' web/index.html
  echo "added hls.js to web/index.html"
fi
echo "Flutter app ready. Try: make web"
