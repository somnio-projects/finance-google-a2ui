# 0028 — The waterfall matches the UI Kit

- **Area:** frontend (`AttributionWaterfall`, the chart primitives under it)
- **Status:** In progress
- **Ticket:** GGU-115
- **Design:** [`assets/0028-waterfall-uikit/waterfall-uikit.png`](assets/0028-waterfall-uikit/waterfall-uikit.png) — the UI Kit A2UI *Waterfall* frame, 1973 × 1740, exported 2026-09-24. Twelve cards: default / selected / loading, at mobile and desktop width, in light and dark, plus a specimen strip of the bar states.
- **Also:** [frontend/0002](0002-chart-primitives-and-waterfall.md) (the first build and its measurements), [frontend/0014](0014-flow-a-drill-down.md) OD-2/OD-3 (the header pill this supersedes), [frontend/0015](0015-loading-states.md) OD-3 (the skeleton seam), [frontend/0020](0020-transition-states.md) OD-7 (reduced motion), [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-13 (charts are primitives), D-15 (goldens)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-24

## 1. Problem

`AttributionWaterfall` is the component Flow A streams, so it is the surface
a viewer looks at longest in the 2026-09-28 demo. It was built (GGU-55) and
extended (GGU-100) against the **component catalog page**, and the UI Kit
frame that design has since published disagrees with what shipped in seven
places. None of them is a bug; all of them are visible from across a room.

| The UI Kit draws | The client drew |
|---|---|
| `+$3,240 · +0.68%` in the gain mark, level with the title | `▲ Net +$3,240 (+0.68%)` on a green pill |
| bars rounded on **all four** corners | rounded on the top two |
| **solid** hairline connectors | dashed connectors |
| the two totals' figures in the title colour at 700 | both muted grey at 500 |
| `Now` **bold** under the closing bar | every axis name muted |
| a **tinted column** behind the selected band, the bar **deepened**, its name bold | a dashed ring around the bar and a blue axis name |
| the selected bucket's detail as a **footer strip** (mobile) or a **floating callout with a pointer** (desktop) | one rounded strip, on every width |
| a **loading** card of grey columns | the Assistant's generic bars-and-pills placeholder |

Two more things the old build did that the frame does not: the header swapped
the net for `buckets[].selected_label` while a bar was selected, and a total's
figure was dropped rather than pushed back inside the plot when it did not fit
centred.

## 2. Measured, not transcribed

Read off the frame's own pixels (PIL, dominant colour per sampled box) rather
than from a token list. The numbers that matter:

| role | UI Kit light | UI Kit dark | what shipped |
|---|---|---|---|
| gain bar | `#2FA584` | `#2A9F7E` | `#12805C` / `#4ADE9E` (`ChartTokens`) |
| loss bar | — | `#E36161` | `#C0362C` / `#FF6B5E` |
| closing total | `#3C90F1` | `#308CF5` | `#4F5DFF` / `#7A83FF` |
| **selected** gain bar | `#1D7059` | `#3ACBA3` | — (new) |
| **selected** loss bar | `#D12A2A` | — | — (new) |
| selected column, gain | `#E8FEF3` | `#132520` | — (new) |
| selected column, loss | `#FFEDEB` | — | — (new) |
| card surface | `#FFFFFF` | `#17181C` | `#FDFBFF` / `#15161C` |
| axis name, muted / bold | `#808184` / `#242425` | — | `#5F6169` for all |

**The frame draws the walk on a lighter base palette than this app's**, which
is what OD-3 is about: its resting gain `#2FA584` is lighter than our
`#12805C`, so its *selected* gain `#1D7059` is lighter than the bar we would
be deepening. The bar marks themselves are **not** changed here (see §6).

## 3. Rulings

- **OD-1 — the header is two of the backend's strings and nothing else.**
  `net.amount.display` · `net.percent.display`, joined by a middle dot, in the
  mark `net.direction` selects, at the title's size one weight heavier. The
  pill, the `▲` glyph and the parentheses are gone with
  `attribution_waterfall_pill.dart`; 0014 OD-3 (the pill's fill) is superseded.

  Two things the frame does not print are **not dropped**. `net.label` opens
  the row's `Semantics` label, so a screen reader still hears *Net, +$3,240,
  +0.68%* — a server-written label kept where the design has no room for it
  (N-9). `buckets[].selected_label` no longer replaces the header while a bar
  is selected, because the frame keeps the net there in every selected card;
  it stays bound on the model and is the caption a future surface can use.

- **OD-2 — the chart's marks follow the frame: four corners, solid runs, and
  two emphasised figures.** A contribution floats between two running totals
  and is a capsule in the frame; squaring its lower edge made it read as
  standing on something. A connector is an unbroken hairline at 1 px — dashes
  are what this app draws for a *reference* line, which is a different
  statement — and `dashed_line.dart` had no other caller, so it is deleted
  rather than left as a helper nothing uses.

  The two totals' figures take `ChartText.total` (the card's title colour at
  700) while a contribution keeps `ChartText.value` in its gain/loss mark. The
  first build derived both from one rule and got the totals wrong; 0002's
  "both totals are muted in text" is corrected here, not re-argued.

- **OD-3 — selection is a column and a deepening, not a ring, and the
  deepened values are derived rather than copied.** The tapped band takes a
  pale tint of its own direction's hue, spanning the plot **and** the axis
  row, so the bold category name reads as part of one column; the bar takes a
  deeper (light) or brighter (dark) fill of the mark it already had.

  Transcribing the frame's `#1D7059` would have made a tapped bar **lighter**
  than the unselected bars beside it, for the reason §2 records. The tokens
  keep the frame's *direction and contrast* applied to this app's marks, and
  `attribution_waterfall_tokens_test.dart` asserts the **direction** — deeper
  in light, brighter in dark, same hue family — rather than the hex, so the
  rule survives the next palette change.

  Selection never moves a bar between the gain and loss families: the colour
  carries a meaning the payload stated.

- **OD-4 — the detail has two presentations and therefore one breakpoint, and
  it is named.** `AttributionWaterfallCard.calloutMinWidth = 520`. Below it,
  the footer strip; at or above it, the callout floating above the bar with a
  pointer aimed at it.

  This app's standing rule is *responsive through `LayoutBuilder` alone, no
  breakpoint* (ADR-L D-13), and this is the one exception. It is an exception
  because **the design ships two different components for one state** and no
  payload field distinguishes them — a chart that recomputed its own layout
  cannot produce a footer strip on one width and a callout on another. The
  threshold is a documented constant in one file, asserted as a constant, and
  exercised at `520 - 1` and at `520`.

  The callout's width is **given** (`232`) rather than measured at layout
  time, and that is what makes the pointer possible: the chart clamps the
  callout into the plot and hands the builder the bar's centre *inside* the
  callout, in one pass. A widget that sized itself would know its own width a
  layout too late.

- **OD-5 — one clamp, two callers, and the interesting one is the callout.**
  `clampedLabelLeft(center, width, plotWidth)` answers where a box of a given
  width starts so that it stays inside the plot: centred when there is room,
  pushed back when there is not, pinned left when it is wider than the plot
  (a negative start would hide a figure's currency and sign, which is the end
  a reader needs). It is arithmetic, so it lives in `finance_charts` with
  numeric tests, beside `waterfallColumn` — the band's full-height rectangle
  the tint needs. Geometry in the package, paint in the app; ADR-L D-13
  unchanged.

  **The 232-wide callout is what actually needs it** (OD-4): a bar near
  either edge would otherwise carry a callout half off the card, and clamping
  it is what makes `pointerDx` differ from the middle.

  For a **value label the clamp never fires, and that is a property rather
  than an accident** — it was measured while mutation-checking. A bar is
  centred in its band and a label is centred on its bar, so a label that
  passes the drop rule (*no wider than its band*) is already inside the plot;
  the clamp can only bite if that rule changes. It is called anyway, one
  function for both, and the test is written as the property — *no figure
  ever leaves the plot, at any width* — instead of an assertion aimed at the
  two totals that would have passed for the wrong reason.

  The drop rule itself is the frame's and is unchanged from 0002: a label
  wider than its band is not drawn. With the catalog's sixteen-step payload
  most labels are dropped at card width, which is what the design's own
  narrow artboard does.

- **OD-6 — the annotation chips stay, although the frame has none.** The
  frame's example carries no `annotations[]`; the backend's does, including a
  `Net` entry. N-9 is not conditional on a design having drawn a place for a
  note, so `AttributionWaterfallNotes` keeps its row under the chart (0014
  OD-2). **What a viewer sees** on the demo payload is the frame's card plus
  one row of neutral chips below the axis.

- **OD-7 — the loading card is the component's own shape and has no words.**
  A title bar, a figure bar opposite it, seven grey columns of uneven height
  with a stub above each. It overrides `ViewComponent.skeleton` (0015 OD-3),
  composes `SkeletonPulse` and declares no `AnimationController`, so reduced
  motion is inherited (0020 OD-7). No caption — unlike `RiskPayoffChart`,
  this card has no tool name the design prints, and inventing one would be a
  word the client made up.

- **OD-8 — four files were split to stay inside the budget**, each along a
  seam that already existed: `waterfall_axis.dart` and
  `waterfall_value_label.dart` out of the chart and its painter,
  `waterfall_overlay.dart` for what a selection adds to the chart's stacks,
  and `attribution_waterfall_body.dart` out of the card, leaving the card as
  chrome, state and the tap.

## 4. Acceptance criteria

1. **AC-1** — the header prints `<net.amount.display> · <net.percent.display>`
   in the mark `net.direction` selects, with no glyph, no parentheses and no
   pill; `net.label` is still reachable as a semantic label.
2. **AC-2** — a selected band is tinted for the full height of the chart, its
   bar takes a deeper (light) / brighter (dark) fill of its own direction's
   mark, its category name is bold, and every other bar is untouched.
3. **AC-3** — the detail shows the payload's `key`, `label`, `detail` and
   `delta.display`; it is the footer strip below `calloutMinWidth` and the
   pointed callout at or above it, and the callout's pointer follows the bar
   even when the callout is clamped against the plot's edge.
4. **AC-4** — an all-positive walk, an all-negative walk, a single bucket,
   twenty buckets and a flat net all render without an overflow, and the
   twenty-bucket case ellipsises its names.
5. **AC-5** — the waterfall's gain and loss marks are the same values the
   holdings chart and the tax-lot table use, asserted against both.
6. **AC-6** — the loading card draws the component's own shape, contains no
   `Text` at all, and holds still under `MediaQuery.disableAnimations`.
7. **AC-7** — every figure on screen is a `*.display` string; no raw member
   reaches a `Text`, and `geometry()` is read only for bar coordinates.
8. **AC-8** — `cd frontend && make gate` green, 100 % line coverage per file.

## 5. Test plan

| AC | How |
|---|---|
| 1 | `attribution_waterfall_headline_test.dart` — the joined string, the three directions, the absent glyph, the semantic label |
| 2 | `waterfall_chart_selection_test.dart` (the tint's rect against the chart's own height), `waterfall_painter_test.dart::gives the selected bar its own fill and leaves the rest alone`, `waterfall_axis_test.dart`, `attribution_waterfall_tokens_test.dart` (the direction, not the hex) |
| 3 | `attribution_waterfall_detail_test.dart`, `attribution_waterfall_callout_test.dart`, `attribution_waterfall_widths_test.dart` (520 − 1 and 520), `waterfall_overlay_test.dart::clamps an overlay that would leave the plot, and still aims it` |
| 4 | `attribution_waterfall_edges_test.dart` — five shapes, built from literals because the backend publishes one example |
| 5 | `attribution_waterfall_tokens_test.dart::agrees with the chart palette and the tax lots on gain and loss` — the `taxlot_tokens_test` idiom |
| 6 | `attribution_waterfall_skeleton_test.dart` — `findsNothing` on `Text`, the `SkeletonPulse`, and the override reached through `ViewComponent.skeleton` |
| 7 | `attribution_waterfall_card_test.dart::never shows a raw decimal`, `waterfall_chart_test.dart::never puts a raw figure on screen` |
| geometry | `packages/finance_charts/test/src/waterfall_columns_test.dart` — the column tiles the plot with no gap, the clamp centres / pins left / pins right / degenerates on a label wider than the plot |
| raster | six goldens: chart default and selected, light and dark; the loading card whole, light and dark. The loading card is the only **whole-card** golden in this suite, and it is one because it has no text — the drift ADR-L D-15 measured is entirely glyph edges |

**Mutation checks**, both run and both watched go red:

| mutation | what turned red |
|---|---|
| `clampedLabelLeft` returns `center - width / 2` unconditionally | 3 of 5 `clampedLabelLeft` cases in `waterfall_columns_test.dart`, **and** `waterfall_overlay_test.dart::clamps an overlay that would leave the plot, and still aims it` |
| `waterfallColumn` returns `band.barLeft/barRight` (the bar) instead of the band | 3 cases in `waterfall_columns_test.dart` (`spans its whole band`, `is wider than the bar it stands behind`, `tiles the plot with no gap`), **and** two widget tests: `waterfall_chart_selection_test.dart::tints the selected band across the plot and its label` and `waterfall_overlay_test.dart::spans the selected band` |

The first mutation is also what found OD-5's real shape: the value-label
suite stayed **green** under it, which is how the clamp turned out to be
unreachable through that caller. The assertion that had been aimed at the two
totals would have passed for the wrong reason, so it was rewritten as the
property.

## 6. Backend gaps — raise as tickets, do not compute

- **BG-1 — a bucket has no caption for its contribution.** The frame's detail
  reads `Contribution +$2,980`; `buckets[]` carries `delta.display` and no
  word in front of it. A Dart constant would not follow the view's `locale`
  option, which is the rule `presentation.md` records for `cost_basis` and
  `proceeds` — *a `label` is a binding*. **What a viewer sees:** the figure
  alone, right-aligned in the direction's mark, in both presentations.
  Suggested shape: `buckets[].delta_label`, as the other captions are sent.

- **BG-2 — the frame's bar palette and this app's disagree, and only design
  can settle it.** §2 has the measurements. `barGain`, `barLoss` and
  `barTotal` are **not** changed by this ticket: they are `ChartPalette`
  roles shared with `HoldingsSummary` and `TaxLotTable`, so re-measuring them
  from one component's frame would silently restyle two other components and
  break AC-5's premise. The divergence is the same class as `specs/frontend/0007`
  OD-2 (the allocation ramp) and belongs in the same conversation.

- **BG-3 — the dark loss-selected state was never exported.** The frame
  carries a selected loss on the light artboard only, so
  `AttributionWaterfallPalette.lossColumn` and `selectedLossBar` in dark are
  the gain recipe applied to the loss hue. Flagged rather than presented as
  measured.

## 7. Out of scope

- The bar palette itself (BG-2) and any change to `ChartTokens`.
- `AttributionDriver` and `AttributionWindow`, which reuse this card's
  reader but have their own frames.
- The catalog gallery's thumbnail of this component, which renders the same
  card at a width far below `calloutMinWidth` and therefore gets the footer
  strip. That is correct and is not the gallery's design question.
- Motion. The frame is static; the streaming entrance a surface makes inside
  the Assistant is spec 0020's, not this one's.
