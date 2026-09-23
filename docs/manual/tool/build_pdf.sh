#!/usr/bin/env bash
# Renders both language sources to PDF with headless Chrome.
#
# Chrome is the renderer because it is the one already on every machine that
# builds this repository — the Flutter web client needs it — so the manual adds
# no new tool to install and no network round trip. `pandoc`, `weasyprint` and
# `prince` are all absent here; a source that only renders on a machine nobody
# has is the same dead end as a PDF with no source.
#
#   bash docs/manual/tool/build_pdf.sh
#
# Override the browser with CHROME=/path/to/chrome if yours lives elsewhere.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manual="$(dirname "$here")"

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [[ ! -x "$CHROME" ]]; then
  for candidate in \
    /usr/bin/google-chrome \
    /usr/bin/chromium \
    /usr/bin/chromium-browser \
    /Applications/Chromium.app/Contents/MacOS/Chromium; do
    [[ -x "$candidate" ]] && CHROME="$candidate" && break
  done
fi
if [[ ! -x "$CHROME" ]]; then
  echo "error: no Chrome or Chromium found. Set CHROME=/path/to/chrome." >&2
  exit 1
fi

# Chrome needs a writable profile it does not share with the user's own, or it
# refuses to start a second instance.
profile="$(mktemp -d)"
trap 'rm -rf "$profile"' EXIT

for lang in en es; do
  src="$manual/user-manual.$lang.html"
  out="$manual/user-manual.$lang.pdf"
  [[ -f "$src" ]] || { echo "error: missing $src" >&2; exit 1; }
  echo "rendering $src"
  rm -f "$out"
  # --no-pdf-header-footer: the page furniture is the document's own, not the
  # browser's "file:///… 1/12" strip.
  #
  # Chrome is backgrounded and polled rather than waited on: headless Chrome
  # writes the PDF and then does not always exit, and `timeout` is not on a
  # stock macOS. Watching for the file is the portable version of both.
  "$CHROME" \
    --headless=new \
    --disable-gpu \
    --no-first-run \
    --no-default-browser-check \
    --user-data-dir="$profile" \
    --no-pdf-header-footer \
    --print-to-pdf="$out" \
    "file://$src" >/dev/null 2>&1 &
  chrome_pid=$!
  for _ in $(seq 1 120); do
    # A non-empty file that has stopped growing is a finished render.
    if [[ -s "$out" ]]; then
      size_a=$(wc -c <"$out")
      sleep 1
      size_b=$(wc -c <"$out")
      [[ "$size_a" == "$size_b" ]] && break
    fi
    sleep 1
  done
  kill "$chrome_pid" 2>/dev/null || true
  wait "$chrome_pid" 2>/dev/null || true
  [[ -s "$out" ]] || { echo "error: $out was not written" >&2; exit 1; }
  echo "wrote $out ($(wc -c <"$out" | tr -d ' ') bytes)"
done
