# 0014 — Flow A's drill-down: the headline pill, the selected bar, the card

- **Area:** frontend (+ backend/0032 for the fields)
- **Status:** In progress
- **Ticket:** [GGU-100](https://somniosoftware.atlassian.net/browse/GGU-100) (the waterfall's binding); the card is Flow A's D2 state, unassigned — none invented
- **Also:** [backend/0032](../backend/0032-attribution-headline-and-driver-detail.md), [0002](0002-chart-primitives-and-waterfall.md) OD-2/OD-3 (closed here), [0011](0011-the-assistant-as-designed.md) OD-4 (the tap), [client/0003](../client/0003-client-backend-contract.md) N-1..N-4, N-9, [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-3
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

The waterfall card headed itself with three neutral chips because the
contract had no field saying which annotation was the net or which way it
pointed (0002 OD-2), and its selected strip showed label, contribution and
running total because the bucket carried nothing else (0002 OD-3). Tapping a
bar sent `drill.attribution.v1` (0011 OD-4) and the agent answered in prose,
because nothing on the backend rendered a detail. backend/0032 adds the
fields and the tool; this spec binds them.

## 2. Measured, not transcribed

`Catalog_AttributionWaterfall.dc.html` (the pill, both artboards; the light
selected ring) and `FlowA-Assistant.dc.html`'s D2 state (dark only), read out
of the inline styles.

| Element | Light | Dark |
|---|---|---|
| headline pill | 12/500 `#12805C` on `#E3F3EC`, r9, pad 5×10 | `#4ADE9E` on `#12291F` |
| selected caption (*NVDA selected*), header right | *inferred* `#4F5DFF` | 10/500 `#B9C0FF` |
| selected bar outline | *inferred* `#4F5DFF` (the catalog page's `ring`) | dashed `3 2` at 1.5 px, `#B9C0FF`, inset 4 |
| selected tooltip's second line | 10/400 — the card prints it under the label in the selection colour | `#B9C0FF` |
| detail card | *inferred*: `HomeTokens.card` `#FDFBFF`, border `#EAE7F0` | bg `#171826`, border `#33354D`, r16, pad 14, gap 12 |
| ticker chip | `HomeTokens.ticker`/`tickerText` | 34×34 r9 `#232036` / `#C9CBFF` 11/500 — byte-identical to `HomeTokens` dark |
| name · caption · contribution | 13.5/500 `text` · 11/400 `muted` · 14/700 `gain`/`loss` by `trend` | `#E5E1E9` · `#A4A6B0` · `#4ADE9E` |
| stat tile | *inferred* fill `#F0EEF5` (`ChartPalette.rule`), r10, pad 9×10, gap 8 | `#101017` |
| tile text | label 10/400 `muted`; figure 12.5/500 (`gain` when the tile has an `up` trend, else `text`); caption 10.5/400 `muted` | same roles, dark |

Light values marked *inferred* were not measured: the design exports no light
D2 state. They take the Home shell's roles and the chart's rule, and
`attribution_driver_tokens_test.dart` records each inference as an equality
with the token it was taken from, so a later measurement replaces a pinned
value rather than a guess.

## 3. What ships

- **The waterfall binds `net`** as `AttributionNet` and draws
  `AttributionWaterfallPill` in the header: `▲ Net +$61,204.05 (+14.51%)`.
  The glyph comes from `net.direction`, never from a sign; the label and
  both signed figures are the backend's; the client adds the space and the
  parentheses. `▲` for `up`, `▼` for `down`, nothing for `flat`.
- **A selected bar swaps the pill for `buckets[].selected_label`** — *NVDA
  selected* — in the selection colour, and the detail strip prints
  `buckets[].detail` under the label. The selected outline is dashed, in the
  same colour; `WaterfallChart` takes a `selectionColor` and the painter
  walks the outline's path metrics (`dashedPath`).
- **The annotations moved under the chart** as `AttributionWaterfallNotes`,
  every one, in arrival order (OD-2).
- **`attribution_driver/`**, a new component directory: `AttributionDriverComponent`
  (`attribution.driver.v1` / `DriverDetail`), a model, the card, the tile and
  its tokens. `make manifest` regenerated the manifest; no hand-written file
  changed for it to reach the conversation, where `ComponentHost` renders it
  from the render intent the `driver_detail` tool emits with `symbol`.
- **The reader split out of the component** (`attribution_waterfall_reader.dart`)
  under the 150-line budget, along the seam it already had: what a payload
  *is* versus the seam and the tap.

## 4. Rulings

- **OD-1 — inferred light values are recorded as inferences.** §2 marks them
  and the tokens test pins each to the token it came from. When design
  exports a light D2, the measurement replaces the pin.
- **OD-2 — the notes move, they do not go.** The design's header carries the
  pill and nothing else; N-9 forbids dropping an annotation. Under the chart
  is where the axis row already ends, and the card's height is the only cost.
  The pill and the *Net* chip both appear — one is the headline, the other
  a compliance sentence; the client does not pick between them (N-5).
- **OD-3 — a loss pill has no measured fill.** The design shows the pill for
  a gain only. A loss keeps the neutral chip fill with the loss mark; a flat
  walk keeps it with the muted mark and no glyph. A measured loss fill is
  design's to add.
- **OD-4 — the glyph is layout, the sign is data.** `▲ +4.20%` is the
  backend's `+4.20%` after a glyph chosen from `trend`. The `@` and `of`
  lines and the ` · … sh · ` detail are **not** composed here: they arrive
  written (`shares.caption`, `day_share.caption`, `buckets[].detail`),
  because a unit word or a preposition beside a figure is prose the backend
  owns (N-9, 0030 OD-1's reasoning).
- **OD-5 — the seed's numbers, not the gallery's.** The card shows
  `+$4,370.40`, `+$48.56`, `134.88%` for NVDA; the design shows `+$2,980`,
  `+$48.60`, `92%`. backend/0032 OD-6 carries the ruling; the component
  test asserts the design's `+$48.60` is **absent**, so nobody "fixes" it
  on the client.
- **OD-6 — the selection colour is the card's token, not the palette's.**
  Adding a role to `ChartPalette` would push `chart_palette.dart` past the
  budget for one consumer; the chart takes the colour as a parameter with
  `barTotal` as its default, which is what the catalog page rings a light
  selection with. `attribution_waterfall_tokens_test.dart` pins the light
  value to `ChartTokens.light.barTotal` and the dark one to
  `HomeTokens.segmentSelected`, so the roles agree without sharing a file.

## 5. Test decision

Component: `net` read with signs and direction, an undeclared direction
raises `net.direction`; each step's `detail`/`selected_label` bound, null on
the totals; the pill in the header above the notes; the selected state shows
the caption where the pill was and the detail line, and the raw `0.45725` /
`90.0000` never reach the screen (N-4). Pill: gain, loss and flat in light
and dark. Tokens: measured values, and the shared roles pinned. Driver card:
the catalog example bound field by field, every raw member absent, the
missing-field and undeclared-trend paths raise, both themes' surfaces, the
trend glyphs and colours. Goldens for the chart regenerated for the dashed
outline (an intended visual change). 100 % line coverage per file, as the
gate requires. The layering, binding and manifest tests are unchanged and
green: adding the component edited no hand-written file.
