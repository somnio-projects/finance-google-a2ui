# frontend/0033 — The donut offers its groupings, and the card is measured

**Ticket:** GGU-145 · **Status:** In progress · **Supersedes nothing.**
**Design source:** `figma.com/design/rFA8ZEEOOvnOyq7IrTObma/A2UI-FINANCE-UI-KIT`,
section `HoldingsSummary`, variants `Default, Light, Desktop` and
`Default, Dark, Mobile`, read through the inspector on 2026-09-28.

## 1. Problem

Two things, and they arrived together because the second was found while doing
the first.

**The donut had a grouping option nobody could reach.**
`holdings.allocation.v1` has declared `group_by` since it shipped — `holding`,
`asset_class`, `sector` — and the only way to change it was for a feature to
send a different option. The design draws a segmented control above the ring;
the client had no control and the payload published no choices.

**The card was built from a mock, and the mock is ours.** Every measurement in
this component came from `.design-refs/*.dc.html`, which several specs called
*"the designer's exported, rendered DOM"*. It is not. Miriam said so plainly on
2026-09-28: *"yo no hice los html / eso es lo que hizo Claude / osea lo que me
pasaron a mi para que mejore."* Those files are a catalog mock **this
repository generated and handed to her as a starting point**. Measuring them
and calling the result "measured from the design" inverts the direction of the
whole handoff, and it is recorded here rather than quietly fixed because the
same sentence is still wrong in `frontend/0031` and `frontend/0004` OD-3.

## 2. Scope

- The backend publishes `groups[]` — value, label, selected — on the payload.
- The client draws a segmented control from it and sends the value back through
  `group_by`, using the `SurfaceEdits` seam.
- The card's header, toggle, ring centre, padding and gaps are re-measured
  against Figma, and the values that were read off the mock are replaced.

Out of scope: the legend rows, the stacked bar, the chart palette, and the
`Risk Payoff` card's own redesign. Each is its own measurement.

## 3. The words come from the server

A client that wrote *"By asset class"* beside a server enum would be authoring
copy for a value the server owns, and it would not follow the `locale` option
(N-1, N-9) — the same reason `direction_label` and every `*Display` string are
server-written. It would also silently narrow the enum: **the design draws two
segments and the option declares three**, and only the server can say whether
the third is missing on purpose.

So `presentation/allocation_groups.py` names every declared choice, in the
order the toggle shows them, and marks the one this render used. The client
draws one segment per entry. The order is decided on the server because N-10
applies to the client.

## 4. What was measured

| Element | Light Desktop | Dark Mobile |
|---|---|---|
| Card | 640 × 255, `radius/lg`, padding `spacing/16`, gap `spacing/16` | 360 × 402, fill `surface/primary` #17181C, border 1px `border/primary` #353A42 |
| Header frame | `Flujo Vertical`, gap `spacing/12` | same |
| Title | 16 / 600 / lh 20, `text/primary` #242425 | style `Title Mobile`: 12 / 600 / lh 100 %, #FFFFFF |
| Gain figure | 13 / 500, `text/positive` #026E4F | 10 / 600, #4ADE9E |
| Gain period | **not read** — see OD-3 | 11 / 400, `text/secondary` #B9BEC6 |
| SegmentedControl | 260 × 32, `radius/full`, padding `spacing/4`, gap `spacing/2`, fill `surface/tertiary` #F6F6F7, no border | 328 × 32, same geometry, fill #26292F |
| Segment, selected | h 24, `radius/full`, padding 4 / 12, fill #FFFFFF, **no border** | same geometry, fill #17181C, **1px #353A42** |
| Segment label | 12 / 500 / lh 100 %, #242425 lit · #56575B unlit | same, #FFFFFF lit · #B9BEC6 unlit |
| Ring centre, total | 18 / 600 / lh 20, `text/primary` | — |
| Ring centre, caption | 14 / 400 / lh 20, `text/secondary` #56575B | — |

## 5. The three structural changes

**The total moved into the ring.** The header is now a title and the all-time
gain, side by side; the total and its caption are inside the donut, which is
where the eye goes on a donut card. The caption is `total.label` — *"Total
market value"* — and **not** design's shorter *"total value"*, because the
label is the server's word (N-1).

**`center.count` / `center.unit` is no longer drawn on this variant**, because
the design draws the total in its place. Dropping server content silently is
N-9, so the header's semantics node reads it out. The other variant
(`headline=false`, where a shell drew the header and the total is already on
screen) keeps drawing the count, so no field is unreachable in both.

**The empty card draws the total where the ring would be.** Moving the total
into the ring quietly removed it from a card that has no ring. An empty
portfolio has a total and it is a real figure; the card test that named `$0.00`
is what caught it, which is the case for naming a figure in a test rather than
asserting that "something" renders.

## 6. The toggle sits on its own line, and that is a measurement

The first version of the header put the toggle beside the title at every
width, and ellipsised the total in the Assistant's 430 pt column. The second
added a **480 pt breakpoint** to fix that — a number nobody had looked up,
invented for the same reason GGU-144 records one component over: the design
was checked at the artboard's width, which is the one width that cannot fail.

Figma's `Header` frame is `Flujo Vertical` with `Espacio spacing/12` on **both**
the 360 and the 640 artboard. There is no arrangement to switch between, so
the breakpoint is gone rather than corrected. The test asserts the single
arrangement at both widths.

## 7. Test decision

- Backend: `test_allocation_groups.py` compares the option's own enum against
  the label table (two declarations of one fact), asserts exactly one segment
  is marked and that it is the grouping the donut was drawn with, and feeds
  every published `value` back through the projection's own options model — so
  a segment the client could tap and the server would 422 fails here.
- Client: the toggle's suite holds the seam (one segment per published entry,
  the backend's words, the value sent back through the declared option, no
  control where no host can honour a tap, no answer while a re-render is in
  flight). `allocation_toggle_tokens_test.dart` asserts the *relationships*
  the artboards carry rather than repeating the hex values, which would be a
  second copy of the same declaration.
- The light/dark border difference is asserted **both ways**: a widget that
  always drew a border would pass a dark-only check.
- `ChartText.subtag` and `ChartText.headline` lost their last caller and were
  deleted. The coverage gap is what surfaced them.

## 8. Open decisions

- **OD-1 — two palettes for one card.** `ChartPalette.title` is `#1A1B20` /
  `#E5E1E9`, from the mock; this card's measured `text/primary` is `#242425` /
  `#FFFFFF`. Reconciling them changes every chart component at once, so
  `HoldingsSummaryTokens` sits beside `ChartPalette` for now. The gain and loss
  tones are deliberately left on `ChartPalette` so the card shows **one** green:
  the measured `text/positive` is `#026E4F` / `#4ADE9E` and is recorded here
  for whoever does that pass.
- **OD-2 — design ships two type scales and the client implements one.** The
  artboards carry named styles `Title` (16) and `Title Mobile` (12), and the
  gain line differs too (13/500 against 10/600). There is no artboard between
  360 and 640, so a breakpoint would be invented — exactly what §6 removes.
  The client draws the Desktop scale at every width until design draws the
  boundary.
- **OD-3 — one value was not read.** The Desktop gain *period*'s size; its
  layer would not select in the inspector. It is drawn at the figure's 13 px
  in Regular. The Mobile artboard puts the period one step **above** the
  figure (11 against 10), so 14 is the likelier answer and this is flagged
  rather than guessed.
- **OD-4 — the design draws two segments, the option declares three.** The
  payload publishes all three and the client draws what it is sent. Whether
  `holding` should disappear is design's call, and it is a one-line change to
  `GROUP_LABELS` when they make it.
- **OD-5 — the app bundles no IBM Plex Sans.** Every artboard sets it; the app
  renders Roboto. Widget tests cannot see this at all (the test font draws a
  full em square per glyph), so it needs a font decision, not a test.
- **OD-6 — closed in this diff.** The false-provenance sentence was in seven
  other files (`frontend/0031` § 2, `frontend/0004`, and five
  `scenario_comparison_*` sources). All now say what the mock is, and point at
  Figma as the authority. The `scenario_comparison` card itself has **not**
  been re-measured against Figma; that is its own ticket, and each file says so
  rather than implying it was.
