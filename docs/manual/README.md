# The user manual

A business-level manual for the application, in English and Spanish, as PDFs
with screenshots. It is written for **the client and the Google demo**: what
the app does, why the idea is worth something, and a walkthrough of the four
tabs and the assistant. No code, no architecture, no API.

| File | What |
|---|---|
| [`user-manual.en.pdf`](user-manual.en.pdf) | The manual, English |
| [`user-manual.es.pdf`](user-manual.es.pdf) | The manual, Spanish |
| `user-manual.en.html` · `user-manual.es.html` | **The sources.** Edit these, never the PDFs |
| `manual.css` | The shared layout, built from the app's own design tokens |
| `assets/*.png` | The screenshots |
| `tool/build_pdf.sh` | Sources → PDFs |
| `tool/capture_screenshots.mjs` | A running stack → `assets/*.png` |

**The Spanish is not a translation of the English.** It is the same manual
written in Spanish. Both are equally complete, and a change to one is a change
to both — neither is derived from the other, so neither can be regenerated
from the other.

## Regenerating the PDFs

```bash
bash docs/manual/tool/build_pdf.sh
```

Headless Chrome prints both sources to A4. Chrome is the renderer because it is
already on any machine that builds this repository — the Flutter web client
needs it — so the manual adds no tool to install and no network round trip.
`pandoc`, `weasyprint` and `prince` were all absent on the machine this was
written on, and a source that only renders on a machine nobody has is the same
dead end as a PDF with no source. Override the browser with
`CHROME=/path/to/chrome` if yours lives somewhere unusual.

## Retaking the screenshots

The pictures are the part that goes stale, so they are captured by a script and
not pasted in by hand. With the stack up and a browser listening:

```bash
# 1. a headless Chrome with the DevTools protocol open
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --user-data-dir=/tmp/ggu-chrome \
  --remote-debugging-port=9333 --hide-scrollbars about:blank &

# 2. the walkthrough, into docs/manual/assets/
node docs/manual/tool/capture_screenshots.mjs \
  --url http://localhost:3000 --email you@example.com --port 9333
```

Node 22 or newer — the script uses the built-in `WebSocket` and `fetch`, so
there is nothing to install. It signs in, walks the four tabs, asks the
assistant one question and writes seven PNGs at 375×812 and 2× — a phone, at
retina, because this is a mobile-first product and the manual should look like
one.

Two details the script encodes rather than leaves to whoever runs it: it parks
the pointer off the content before every capture, so no hover state leaks into
a picture of a screen, and it waits long enough after sending the question for
a real model turn to finish.

After retaking them, **rebuild the PDFs and check the images by eye** before
committing. A screenshot that came out half-painted is worse than none.

## What these screenshots were taken against

| | |
|---|---|
| Release | **`local+5cb9a40`** — the same string `GET /release.json` and the API's `/health` both reported |
| Web client | `http://localhost:3000` |
| API | `http://localhost:8040`, seeded data, Gemini configured |
| Date | 2026-09-22 |
| Signed in as | `lbertuzzi@somniosoftware.com`, through the backend's e-mail sign-in |

The release string is on the cover of both PDFs for the same reason `/health`
carries it: a screenshot that cannot be traced to a build is a screenshot of
nothing in particular (GGU-93).

## What the manual is careful about

**It says the portfolio is simulated, early and plainly.** Section 2 of both
languages is nothing else, and the cover says it too. The application itself is
honest about this on screen — the `Simulated portfolio` badge, the
`Simulated activity — resets each session` line, the assistant's `Simulated`
badge — and the manual is not allowed to be less honest than the product. There
is no market-data licence, no broker and no way to move money behind this
repository, and no sentence in the manual may imply otherwise. The root
[`README.md`](../../README.md) § *What is real and what is not* is the source of
truth for that table; keep them in step.

**It does not document the rough edges as features.** At the time of writing the
assistant had two known defects being fixed — a chart that could show an
all-time figure beside a sentence about today, and a follow-up chip that did not
reach the view it named. Neither is described here and neither is screenshotted.
The assistant screenshot is a question whose answer is correct end to end. If a
future capture run produces an answer that is wrong, **retake it**; do not ship
it with a caption explaining it away.

**Its branding is the product's own.** There is no Somnio document template, so
every colour in `manual.css` is copied from `frontend/app/lib/theme/` or
`frontend/app/lib/charts/chart_tokens.dart` — files that are themselves measured
from the design rather than generated — and the cover mark is the sign-in
screen's mark rebuilt in CSS. Each value carries a comment naming the Dart file
it came from, so a palette change in the app can be followed here.

## When the app changes

The manual is a claim about what the app does today. A change to a tab's
layout, a control, or what the assistant can answer makes some sentence in both
languages false. Retake the screenshots, fix both sources, rebuild both PDFs,
and update the release string in this file and on both covers — in the same
pull request as the change, the way a diagram is.
