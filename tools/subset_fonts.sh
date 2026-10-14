#!/usr/bin/env bash
# Bundle the app fonts small enough for < 50 kbps users: fixed weights only, Latin + ₹ glyphs only.
#   bash tools/subset_fonts.sh        -> frontend/assets/fonts/*.ttf (+ OFL licences)
# Sources: github.com/google/fonts (SIL Open Font License). Needs `uvx` (uv) for fonttools.
# Theme B: Space Grotesk for UI text, Space Mono for labels, prices and ids (assets/config/ui/theme.yml).
set -euo pipefail
OUT="$(cd "$(dirname "$0")/.." && pwd)/frontend/assets/fonts"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
SRC=https://raw.githubusercontent.com/google/fonts/main/ofl
FT=(uvx --from "fonttools[woff]==4.55.3" fonttools)

# Basic Latin, Latin-1, dashes/quotes/ellipsis/bullet, ×, minus, ₹, ™, arrows
UNICODES="U+0020-007E,U+00A0-00FF,U+2010-2027,U+2030-203A,U+00D7,U+2212,U+20B9,U+2122,U+2190-2193"

curl -fsSL -o "$TMP/SpaceGrotesk.ttf" "$SRC/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf"
curl -fsSL -o "$TMP/SpaceMono-Regular.ttf" "$SRC/spacemono/SpaceMono-Regular.ttf"
curl -fsSL -o "$TMP/SpaceMono-Bold.ttf" "$SRC/spacemono/SpaceMono-Bold.ttf"
rm -f "$OUT"/*.ttf "$OUT"/OFL-*.txt
mkdir -p "$OUT"
curl -fsSL -o "$OUT/OFL-SpaceGrotesk.txt" "$SRC/spacegrotesk/OFL.txt"
curl -fsSL -o "$OUT/OFL-SpaceMono.txt" "$SRC/spacemono/OFL.txt"

# Space Grotesk ships as one variable font; cut the fixed weights theme.yml uses.
for w in 400:Regular 500:Medium 600:SemiBold 700:Bold; do
  "${FT[@]}" varLib.instancer "$TMP/SpaceGrotesk.ttf" "wght=${w%%:*}" -o "$TMP/SpaceGrotesk-${w##*:}.ttf" -q
done

for f in SpaceGrotesk-Regular SpaceGrotesk-Medium SpaceGrotesk-SemiBold SpaceGrotesk-Bold SpaceMono-Regular SpaceMono-Bold; do
  "${FT[@]}" subset "$TMP/$f.ttf" --unicodes="$UNICODES" --layout-features='kern,liga,calt,tnum,lnum' \
    --drop-tables+=DSIG --no-hinting --desubroutinize --output-file="$OUT/$f.ttf"
done
ls -l "$OUT"
