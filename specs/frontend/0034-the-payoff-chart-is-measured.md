# frontend/0034 — The payoff chart draws what the design draws

**Ticket:** GGU-146 · **Status:** In progress
**Design source:** `figma.com/design/rFA8ZEEOOvnOyq7IrTObma/A2UI-FINANCE-UI-KIT`,
section `Risk Payoff Chart`, variant `Comparison, Light, Desktop` (640 × 426,
`radius/lg`, padding `spacing/20`, gap `spacing/12`).
**Closes** `frontend/0005` OD-1 and OD-8, both of which recorded a *payload*
gap. Both fields now exist.

## 1. Problem

The card drew a plot, a zero rule, curves and a price row. The design draws
seven things it did not, and **four of them the client was forbidden to
invent**:

| Missing | Why the client could not add it |
|---|---|
| Labels on the value axis | It would have to pick the rungs *and* format them — N-2 and N-1 in one step, and it would not follow `locale` |
| *Loss* / *Gain* inside the regions | Copy the server owns; an English constant here is a word nobody can translate |
| The dashed break-even rule | `frontend/0005` OD-1: the payload could not say where break-even was |
| A marker at the current price | The same gap |

The other three — the legend beside the title rather than under the plot, the
second series, and the caption under the chart — were only arrangement.

## 2. Two fields, and where they had to live

`payoff.curve.v1` gains `value_ticks[]` (an ADR-E pair per rung) and
`zones {loss, gain}`. Both are written in
`presentation/payoff_axis.py`, beside `payoff_markers.py`, for the reason that
module already argues: **a figure or a word the widget shows is the server's,
or it is not the contract's.**

The ladder is chosen by a step search over 1, 2, 5 and 10 times a power of
ten, aiming for five rungs and never exceeding them. It always contains zero,
because zero is the line the whole chart is read against. Reproducing the
artboard's own ladder — a 20 k span in five rungs of 5 k — is a test, which is
what makes the search a measurement rather than a preference.

**`markers` was already there**, added by spec `backend/0024` §4 for a
different reason (to stop the client placing a rule by matching the English
string `"Break-even price"`). OD-1 said the payload "lacks" the field; it had
stopped lacking it and nothing had gone back to read the note. Two of the four
gaps above were already closed when this ticket opened.

## 3. The regions turn ninety degrees

The wash used to say *profit or loss* — gain above the zero rule, loss below.
The design's says *how far the underlying moved*: a region either side of
**break-even**, so the boundary is a price and the split is vertical.

Which side loses is read from the curve's own sign at its lowest price, so a
**sale mirrors** without a flag travelling down from the payload. With no
break-even marker at all the old horizontal split stays as the fallback — a
payload that predates the field must still render.

## 4. The value axis needs room, so the plot gives some up

The rung labels live to the left of the plot, in a gutter whose width is the
**widest label, measured**. A constant would be wrong in both directions:
`$0.00` wastes half of it and `-$1,250,000.00` overflows it, and which one
arrives is the payload's decision (N-1 — the client never shortens one).
Measuring in the `LayoutBuilder` is a layout pass, not arithmetic on a figure.

A 16 pt band above the plot carries the break-even's caption, which is the
marker's own `label` and its own `at.display`, joined and written by neither.

## 5. The golden was proving the fallback

Until this ticket the payoff golden built its subject from **two** fields of
the model, `series` and `tickLabels`. When the markers, the rungs and the
region words arrived, the goldens re-rendered **byte-identically** and said
nothing — and a golden's silence reads exactly like a pass.

That is the lesson worth keeping, and it generalises past this card: *a golden
over a subject assembled from part of the model proves that part.* The subject
now binds the whole model, and the regenerated rasters show the vertical
regions, the dashed rule, the gutter, the dot and both region words.

**And the first regeneration froze a bug.** `paintValueRungs` was called
*after* the canvas had been translated by the gutter and then subtracted from
the gutter again, so every rung label landed one gutter too far right —
inside the wash rather than beside it. `--update-goldens` blessed it without
complaint, the suite went green, and it was found by opening the card in a
browser.

`--update-goldens` is not a check, it is a **statement that what is on screen
is correct**, and nothing in the gate distinguishes a deliberate visual change
from a defect. On a ticket that regenerates goldens, look at the raster before
committing it — and, where the defect is a position rather than a colour, look
at the running app, because a golden's text is a row of em squares and an
overlap with a label reads as normal there.

**Then the goldens failed on the runner at 1.545 % against a 1.5 % tolerance**,
identically in both themes at a largest channel delta of 163/255 — the
signature of glyph rasterisation, not of colour. ADR-L D-15 calibrated that
tolerance on a subject with a tick row and little else; this one now carries a
rung ladder, a caption and two region words. The threshold goes **down**, never
up to absorb a failure (`frontend/testing.md` §6), so the **subject** shrank
instead: the goldens are cropped to a text-free band of the plot.

Two things about that crop are worth copying:

- **A pixel census of the committed PNG is the proof, not the constants it was
  derived from.** Cropping vertically left 2 255 px of label ink; cropping 64
  from the left still left a 16 px column of it; 96 leaves **zero**. The
  constants looked right all three times.
- **A translucent wash needs its background stated.** Captured over nothing,
  the 7 % wash came back as its unpremultiplied saturated colour — a red and a
  green filling 72 % of the raster — and the golden stopped resembling the
  card. The subject now names the surface it composites over.

What the crop can no longer see is asserted in
`payoff_chart_gutter_test.dart`: `rungLabelLeft` is always negative, so a
label cannot be inside the plot. It tests the **offset function** rather than
the pixels — a census of the rendered chart was written first and `toImage`
inside a widget test hangs rather than failing, and a check that cannot be run
is worth less than a narrow one that can. It does catch the exact defect:
`gutter - rungGap - width` is positive whenever the gutter exceeds the label,
which is every real payload.

## 6. Test decision

- Backend: `test_payoff_axis.py` asserts the ladder contains zero, is evenly
  spaced and ascending at four orders of magnitude, spans its own curve
  without stopping a whole step short of either end, reproduces the artboard's
  5 × 5 k ladder, and is written in the payload's own money format. The
  flat-curve case is built by flattening a real curve rather than constructing
  an invalid one, because `PayoffCurve` requires three ascending points and a
  fixture dodging its own validators tests a shape the domain cannot produce.
- Geometry: `payoff_marks_test.dart` (pure Dart) asserts the marker
  **interpolates** between two samples rather than snapping to the nearer one
  — snapping would put the dot 50 px off the line it sits on — and that the
  zones mirror for a sale and clamp rather than invert for a break-even off
  the plot.
- Client: `payoff_chart_marks_test.dart` asserts each new field is bound from
  the payload and **not** from a constant, that a missing `markers` block
  raises the path (N-3), and that the legend sits opposite the title.
- The step search's unreachable branch was deleted rather than tested:
  `magnitude` is the largest power of ten at or below `rough`, so the last
  mantissa cannot fail, and a branch no input can take is a coverage report
  that never goes away.

## 7. Open decisions

- **OD-1 — the payoff palette was not re-measured, and that is a gap this
  ticket opened deliberately.** GGU-145 established that
  `.design-refs/*.dc.html` is our own mock; `payoff_tokens.dart` still carries
  values from it. The Figma session this session had been reading went away
  mid-ticket and came back as an anonymous viewer, which has no inspector, so
  the colours could not be read. **The structure here is the design's and the
  colours are still the mock's**, which is stated rather than papered over.
  What remains to read: the two region washes and their alphas, the break-even
  amber, the axis-label grey, the marker dot and the two series colours.
- **OD-2 — the step search exists on both sides of the wire.** `_STEPS` in
  `payoff_axis.py` and `niceStep` in `finance_charts` are the same mantissa
  set, written twice, and nothing compares them. They decide different axes —
  value on the server, price on the client — so they are not duplicates in the
  ordinary sense, but they will drift, and the drift will be invisible.
- **OD-3 — Miriam's own note on the kit is still open**, verbatim:
  *"Categorical segment colors … are NOT yet bound to design tokens - no
  categorical/chart palette exists in this file yet, flagged for Miri."* The
  two series colours are in that gap, which is part of why OD-1 is not just a
  matter of finding a spare hour with the inspector.
- **OD-4 — the second series has no second source.** The artboard draws *Hold*
  against *After proposed sell*; `payoff.curve.v1` renders one line, and the
  client has always supported more (`series` is a list). Nothing asks the
  backend for the comparison line, so the two-series variant is reachable only
  from a payload nothing currently produces.
