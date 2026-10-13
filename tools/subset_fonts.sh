#!/usr/bin/env bash
# Bundle the app fonts small enough for < 50 kbps users: fixed weights only, Latin + ₹ glyphs only.
#   bash tools/subset_fonts.sh        -> frontend/assets/fonts/*.ttf (+ OFL licences)
# Sources: github.com/google/fonts (SIL Open Font License). Needs `uvx` (uv) for fonttools.
set -euo pipefail
OUT="$(cd "$(dirname "$0")/.." && pwd)/frontend/assets/fonts"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
SRC=https://raw.githubusercontent.com/google/fonts/main/ofl
FT=(uvx --from "fonttools[woff]==4.55.3" fonttools)

# Basic Latin, Latin-1, dashes/quotes/ellipsis/bullet, ×, minus, ₹, ™, arrows
UNICODES="U+0020-007E,U+00A0-00FF,U+2010-2027,U+2030-203A,U+00D7,U+2212,U+20B9,U+2122,U+2190-2193"

curl -fsSL -o "$TMP/Poppins-SemiBold.ttf" "$SRC/poppins/Poppins-SemiBold.ttf"
curl -fsSL -o "$TMP/Poppins-Bold.ttf" "$SRC/poppins/Poppins-Bold.ttf"
curl -fsSL -o "$TMP/Inter.ttf" "$SRC/inter/Inter%5Bopsz,wght%5D.ttf"
mkdir -p "$OUT"
curl -fsSL -o "$OUT/OFL-Poppins.txt" "$SRC/poppins/OFL.txt"
curl -fsSL -o "$OUT/OFL-Inter.txt" "$SRC/inter/OFL.txt"

# Inter ships as one variable font; cut fixed instances (text optical size 14).
for w in 400:Regular 500:Medium 600:SemiBold; do
  "${FT[@]}" varLib.instancer "$TMP/Inter.ttf" "wght=${w%%:*}" opsz=14 -o "$TMP/Inter-${w##*:}.ttf" -q
done

for f in Poppins-SemiBold Poppins-Bold Inter-Regular Inter-Medium Inter-SemiBold; do
  "${FT[@]}" subset "$TMP/$f.ttf" --unicodes="$UNICODES" --layout-features='kern,liga,calt,tnum,lnum' \
    --drop-tables+=DSIG --no-hinting --desubroutinize --output-file="$OUT/$f.ttf"
done
ls -l "$OUT"
