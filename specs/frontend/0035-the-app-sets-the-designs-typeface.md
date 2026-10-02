# frontend/0035 — The app sets the design's typeface

**Ticket:** GGU-147 · **Status:** In progress
**Closes** `frontend/0033` OD-5 and `frontend/0034`'s half of the same note.

## 1. Problem

**Every artboard of the design kit sets IBM Plex Sans. The app shipped
Roboto**, the platform default, and had bundled no font at all.

It went unnoticed for eleven components because **no test in this repository
can see it**. `flutter test` renders every glyph in the test font as a full em
square, so typography is invisible to a widget test *and* to a golden
(`frontend/testing.md` §6 says so in as many words). The only checks that
could have caught it are a person looking at the running app, and a
measurement pass — which is how it was found: GGU-145's inspector run
recorded `Fuente: IBM Plex Sans` on every text node it read.

A typeface is not a detail here. It changes the width of every string, which
is what a measured layout is measured *against*: the gutter of the payoff
chart's value axis is sized from the widest rung label, and the donut's total
was moved inside a ring whose hole it has to fit.

## 2. Bundled, not fetched

Three weights ship in `app/assets/fonts/` under the SIL Open Font License,
declared in `pubspec.yaml`.

**Not `google_fonts`.** That package fetches at run time. This client is a
static Hosting release with no server, so a lookup would be a network
dependency on first paint and a `connect-src` the CSP deliberately does not
grant — `font-src 'self' data:` already covers a bundled file and needs no
change, which is the second reason.

**Three weights, and only three**, because the measurements name exactly
those: 400 for body and captions, 500 for a segment label and a gain figure,
600 for a title and the total in the donut. A widget asking for 700 gets a
synthesised bold, which is the honest failure — the design does not use one.

## 3. It has to be named twice

`ThemeData.fontFamily` reaches every `Text` in the tree, because a `Text`
whose own style has `inherit: true` merges onto the default. It reaches **no
glyph a `CustomPainter` draws**: a painter has no context and a `TextPainter`
takes a complete style.

So the charts name it too. Every painted string in this app goes through
`ChartText`, which is the one place the styles are built, so the family is
added there rather than at eleven call sites.

The constant lives in `charts/chart_text.dart` and `AppTheme` reads it back
from there, so the literal has one home — which the colour rule already
requires for a `Color` and is no different for a family name.

It spent one gate run in a leaf of its own, `theme/app_typeface.dart`, to keep
the import direction obvious. **A file holding nothing but a `const` gets no
lcov record at all**, so the per-file coverage contract reported it as
untested with no way to fix it, and the answer was not to loosen the check but
to notice the constant already had a home: the file that must name it is the
file that should own it.

Half-applying it would have looked like a font bug rather than a missing
line: every widget in Plex and every axis label in Roboto, on one card.

## 4. Test decision

**There is no test, and that is the finding rather than an omission.**
`flutter test` draws the test font's em square for every glyph, so a suite
cannot tell one family from another; a golden cannot either, for the same
reason, and `frontend/testing.md` §6 already records that goldens prove
"bars, connectors, colours and layout, **not** typography".

What is asserted instead is the *wiring*, which is what could silently regress:
`app_theme_test.dart` checks that both themes carry the family, and
`chart_text_test.dart` that every style `ChartText` builds names it — the
second is the one that matters, because it is the half a theme change cannot
fix and the half nothing else would notice.

Whether the glyphs are really Plex is proved by looking at the running app,
and the PR carries that.

## 5. Open decisions

- **OD-1 — the bundle grows by ~600 kB.** Three TTFs, uncompressed in the
  build; Hosting serves them gzipped and they are cached across releases.
  Subsetting would cut it, and would also silently drop a glyph the day a
  payload arrives in a locale the subset does not cover — `locale` is a
  declared option of every projection, so the risk is real rather than
  theoretical. Not subsetted, deliberately.
- **OD-2 — the design names weights this does not ship.** Only 400/500/600
  were measured. If a page turns out to set 300 or 700, it is one line in
  `pubspec.yaml` and one more file, and until then a synthesised weight is
  preferable to a guessed download.
