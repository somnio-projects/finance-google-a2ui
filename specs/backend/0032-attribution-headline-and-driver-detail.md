# 0032 — The waterfall's headline, and the card a tapped bar opens

- **Area:** backend (+ frontend/0014 for the client half)
- **Status:** In progress
- **Ticket:** [GGU-100](https://somniosoftware.atlassian.net/browse/GGU-100) (the waterfall's fields) · the drill-down card is Flow A's D2 state, unassigned — no GGU number exists for it and none is invented here
- **Also:** [0005](0005-presentation-layer.md) (the projection), [0022](0022-surface-actions.md) §3.3 (`drill.attribution.v1`), [0024](0024-contract-serves-the-designs.md) §1 (the gap this closes), [0026](0026-the-home-shell.md) (`day_change`), [0028](0028-holdings-and-activity.md) OD-1 (a page-less card, named by us), [0029](0029-the-turn-recommends-its-chips.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) D-5/D-12/D-15
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

Two things the design draws had no field behind them.

`Catalog_AttributionWaterfall.dc.html` heads the card with a pill,
*▲ Net +$3,240 (+0.68%)*, and its selected state prints
*+4.2% · 90 sh · $1,204.66* under the tapped bar. `attribution.waterfall.v1`
carried neither: the net was one of three prose `annotations[]` with nothing
saying which one it was or which way it pointed, and a bucket knew its
contribution and running total and nothing else. The client drew neutral
chips and a three-figure strip, and frontend/0002 OD-2/OD-3 recorded the gap.
GGU-100 is the ticket that rules on it.

`FlowA-Assistant.dc.html`'s D2 state — *Dark · segment tapped → recomposed
detail* — shows what a tap should compose **below** the waterfall: a card
with the ticker, the name, *Top contributor today*, the contribution, and
three tiles (price move, shares at their price, share of the day's gain).
Spec 0022 built the tap: `drill.attribution.v1` sends the symbol and the turn
receives *"Break down the contribution of NVDA…"*. But the model had no tool
that answers it with a component, so the drill was a prompt that ended in
prose. The mechanism was real; the recomposition was not.

## 2. What ships

**`attribution.waterfall.v1`, criterion by criterion.**

- **AC-1** — `net`, a new `Delta` fragment: `label` (*Net*), `amount` as a
  **signed** ADR-E money pair, and `direction` (`up / down / flat`). The pill
  binds it. Computed as `end − start`, the walk's own delta, and nothing else.
- **AC-2** — `net.percent`, a signed ADR-E ratio of `net.amount` over the
  walk's start (`change_ratio`, the domain's), printed at the render's
  precision (`+14.51%` at the default two decimals).
- **AC-3** — every `buckets[]` step is now a `HoldingStep`: `move` (the
  step's own signed percentage move, market value over cost), `units`
  (`QuantityDisplay`) and `price` (the unit price as quoted, through
  `price_display`), plus two written lines: `detail`
  (*+45.72% · 90 sh · $1,204.66* — separators and the unit word are the
  backend's, N-9) and `selected_label` (*NVDA selected*, the header's caption
  while that bar is selected).
- **AC-4** — orientation: see OD-2. No field.
- **AC-6** — `cumulative` stays; design binds it and the chart places every
  bar with it.
- The A2UI adapter publishes `net` beside `start`/`end`; each step's new
  fields travel inside `steps[]`. Both catalog artefacts regenerated; the
  example's existing literals are unchanged (the walk, its order, its
  annotations, its actions).

**`attribution.driver.v1` — `DriverDetail`.** A new projection, a page-less
card named by us (OD-1), fitness 0 so the selection rule never volunteers it
(0028 OD-1's rule). Options: `DisplayOptions` plus `symbol` (the curated
`Symbol` literal, default `NVDA`, the design's driver). Payload:

| Field | Carries |
|---|---|
| `symbol` · `name` · `caption` | the chip, the name, *Top contributor today* — or the other four captions (OD-4) |
| `contribution` · `trend` | the holding's day change, signed, with its direction |
| `price_move` | `label` *Price move*, `percent` (signed ratio of price over previous close), `amount` (signed), `trend` |
| `shares` | `label` *Shares*, `units`, `price` (as quoted), `caption` *@ $1,204.66* |
| `day_share` | `label` *Of day gain* / *Of day loss*, `percent` (contribution over the day's move), `total` (the day's move, signed), `caption` *of +$3,240.18* |

Every figure comes from one domain function, `app.domain.driver.driver_detail`,
which composes `day_change`'s arithmetic for one symbol and ranks it among
the rest. A symbol the reference knows but the portfolio does not hold renders
a **422** naming it (the same shape as an unknown `fields` section) — OD-3.

**`driver_detail`, an agent tool.** `agent/tools/driver_detail.py`, the shape
of `compute_attribution`: one argument, `symbol: Ticker`; every figure a
pre-formatted string; `standing` and `rank` as words and an ordinal so the
model can say where the holding stood; a render intent for
`attribution.driver.v1` with `{symbol}`. For a symbol not held it answers
`{held: false}` and asks for **no** surface — the leaf 0022's GGU-31 asked
for, answered rather than failed. The tool and the projection read the same
`DriverDetail`, so what the model says and what the card shows cannot differ.

`Delta` is a new fragment (ADR-K D-16), tested. The signed pairs moved from
`summary_figures` to `displays.signed_money` / `signed_percentage` — three
projections print a change now, and the pylint duplication gate would have
objected to a third copy — and `summary_figures` keeps its wrappers.

## 3. Rulings

- **OD-1 — the card is named by us.** No catalog page exists for it; it is a
  state of Flow A. `DriverDetail`, added to `DESIGN_CATALOG` in
  `test_component_names.py` beside `PortfolioSummary`, `PositionList` and
  `ActivityTimeline`, under the same rule (0028 OD-1). It carries no
  `guidance`: a sentence written here would be indistinguishable from one a
  designer approved (`presentation.md` §6).
- **OD-2 — orientation is client layout (GGU-100 AC-4).** The design's Zone 2
  declares `"orientation": "horizontal | vertical"`. A projection describes
  *what* the walk is; which way a client lays it out depends on the width it
  is given, which the server does not know — the same reasoning ADR-L D-14
  gives for value-to-pixel mapping. No option, no field; the client's
  `LayoutBuilder` decides. If a caller ever needs to *ask* for one, it is a
  declared option on a `v2`, not a payload fact.
- **OD-3 — a held-nowhere symbol is a 422, not an empty card.** The options
  model accepts every curated symbol (the bound shared with `order.ticket.v1`
  and the drill action), so `TSLA` validates and has no card behind it. The
  projection raises `ValidationFailedError` naming the symbol; the tool
  checks first and never asks for a surface it knows will 422. The render
  intent path cannot reach the 422 either: an intent for an unheld symbol
  is only ever produced by the tool, which refuses to produce it.
- **OD-4 — the caption is a table, not prose the model writes.** Five
  standings — `top_contributor`, `contributor`, `top_detractor`, `detractor`,
  `unchanged` — ranked by the size of the day change among holdings on the
  same side, ties on the ticker. *Top contributor today* is the design's; the
  other four (*#2 contributor today*, *Top detractor today*,
  *#3 detractor today*, *Unchanged today*) are written here so every bar a
  reader can tap has a caption, and the tool passes `standing`/`rank` rather
  than the sentence so the model does not re-author it.
- **OD-5 — the waterfall's window and the card's window differ, and it is
  recorded.** The walk is *unrealised P/L*, cost basis to market value; its
  net is therefore `+$61,204.05 (+14.51%)` over the seed, not the design's
  `+$3,240 (+0.68%)`, which is the **day's** move. GGU-100 asks for the walk's
  net as a first-class field, and that is what `net` is: end minus start,
  bound, never a second computation. The drill-down card is the day's — Flow
  A's question is *What moved my portfolio today?* — computed from
  `day_change` as 0026 does, and its `day_share.total` is exactly the hero's
  `+$3,240.18 (+0.68%)`. A waterfall that walks the day would be a `window`
  option on the projection (ADR-K D-3), which no ticket has asked for; the
  gap is written here rather than closed by momentum.
- **OD-6 — the seed's figures are served, not the gallery's.** The design
  prints `+$2,980`, `+$48.60`, `92%`; the seed gives NVDA `+$4,370.40`,
  `+$48.56` and `134.88%` — above one because VOO detracted `-$2,295`. 0025's
  rule: the component is reproduced, the sample data is design's to fix.

## 4. Test decision

Domain: every standing reachable from the seed (`NVDA`, `AAPL`, `VOO`, `BND`,
`USD`), rank counted on the same side only, normalisation, the unheld leaf,
a flat day's zero share. Presentation: the headline's signs and direction;
`net_of` over a gain, a loss, a flat walk and a walk from nothing; the step
figures with the half-even rounding written down (`0.45725 → +45.72%`); the
card's three tiles with their captions, a detractor's words, the ranks,
locale and precision, the 422, the adapter, fitness. Tool: display strings
only (the `Display` suffix rule), the render intent's normalised symbol, the
`held: false` leaf, argument rejection, the description. The inventory test
now names nine display paths and asserts every raw member is `.amount`,
`.value` or `.units`. Registry lists extended: `SHIPPED_VIEWS`,
`EXPECTED_TOOLS`, `DESIGN_CATALOG`. Both catalog artefacts regenerated and
diffed by the gate.
