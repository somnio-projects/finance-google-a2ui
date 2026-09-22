#!/usr/bin/env bash
# Build docs/guides/feeding-charts-and-schema-mutations.pdf from the Markdown.
#
# The Markdown in docs/guides/ is the source of truth; the PDF is a generated,
# committed export (see docs/guides/README.md for why that exception exists).
#
#   bash docs/guides/tool/build_pdf.sh            # from the repository root
#
# Pipeline, with no new repository dependency:
#   Markdown --(tool/md_to_html.py)--> one HTML page
#           --(headless Chrome, Mermaid from a pinned CDN)--> PDF
#
# Needs: python3, Google Chrome, and network access for the Mermaid CDN.
# Screenshots are downscaled into the build directory with `sips` (macOS) or
# ImageMagick when either is available; the originals in assets/ are untouched.

set -euo pipefail

GUIDES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$GUIDES/feeding-charts-and-schema-mutations.pdf}"
TITLE="Feeding charts and schema mutations"
# Longest edge, in pixels, an embedded screenshot is downscaled to, and the
# JPEG quality it is re-encoded at. The page is A4: above this the file grows
# and the reader sees nothing more. The originals in assets/ stay PNG and are
# never touched — only the copies staged for this build are converted, which is
# also what keeps the committed PDF under the repository's 2 MB per-file limit
# (`check-added-large-files` in .pre-commit-config.yaml).
MAX_EDGE=860
JPEG_QUALITY=70

BUILD="$(mktemp -d "${TMPDIR:-/tmp}/a2ui-guides-pdf.XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT

echo "==> staging assets in $BUILD"
mkdir -p "$BUILD/assets"
cp "$GUIDES"/assets/*.png "$BUILD/assets/"

converted=0
if command -v sips >/dev/null 2>&1; then
  for png in "$BUILD"/assets/*.png; do
    sips -Z "$MAX_EDGE" -s format jpeg -s formatOptions "$JPEG_QUALITY" \
      "$png" --out "${png%.png}.jpg" >/dev/null
    rm -f "$png"
    converted=$((converted + 1))
  done
elif command -v magick >/dev/null 2>&1; then
  for png in "$BUILD"/assets/*.png; do
    magick "$png" -resize "${MAX_EDGE}x${MAX_EDGE}>" -quality "$JPEG_QUALITY" \
      "${png%.png}.jpg"
    rm -f "$png"
    converted=$((converted + 1))
  done
else
  echo "    (no sips or magick — embedding the screenshots at full size)"
fi
echo "    ${converted} screenshot(s) resized to ${MAX_EDGE}px and re-encoded"

echo "==> rendering HTML"
python3 "$GUIDES/tool/md_to_html.py" \
  "$BUILD/index.html" "$TITLE" \
  "$GUIDES/feeding-charts.md" \
  "$GUIDES/schema-mutations.md"

# The staged copies are JPEG now; the Markdown still says .png, as it should.
if [ "$converted" -gt 0 ]; then
  sed -i.bak 's|\(src="assets/[^"]*\)\.png"|\1.jpg"|g' "$BUILD/index.html"
  rm -f "$BUILD/index.html.bak"
fi

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [ ! -x "$CHROME" ]; then
  for candidate in \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "$(command -v google-chrome || true)" \
    "$(command -v chromium || true)"; do
    [ -n "$candidate" ] && [ -x "$candidate" ] && CHROME="$candidate" && break
  done
fi
[ -x "$CHROME" ] || { echo "no Chrome found; set CHROME=<path>" >&2; exit 1; }

echo "==> printing with $(basename "$CHROME")"
# --virtual-time-budget lets Mermaid fetch from the CDN and lay every diagram
# out before the page is printed; without it the diagrams come out as text.
"$CHROME" --headless=new --disable-gpu --no-sandbox \
  --no-pdf-header-footer --virtual-time-budget=30000 \
  --print-to-pdf="$OUT" "file://$BUILD/index.html" 2>/dev/null

echo "==> $OUT ($(du -h "$OUT" | cut -f1))"
