# 0004 — The scenario comparison card

- **Area:** frontend
- **Status:** Draft
- **Ticket:** GGU-59 · serves GGU-18 (Flow B surfaces) and GGU-42 (design) · builds on GGU-55
- **Related specs / ADRs:** [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-3/D-13/D-15, [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [`backend/0017`](../backend/0017-scenario-comparison.md) (the projection this binds), [`frontend/0002`](0002-chart-primitives-and-waterfall.md), [`client/0003`](../client/0003-client-backend-contract.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

`scenario.comparison.v1` has been on the backend since GGU-41 and nothing
renders it. It answers the question the tax-lot surface provokes — *"…and
would a different lot-selection method be better?"* — by costing the **same**
sale under FIFO, LIFO and HIFO and putting the three outcomes side by side. On
the seeded BTC position the methods disagree by $2,520.00 and disagree on
whether the result is short- or long-term.

Until this card exists, the only way to show that comparison is to let the
model line three tool results up itself, which is the model arranging
financial figures into a table — exactly what ADR-E and ADR-K D-5 forbid.

This card is also the place in the app where the numbers rule is under the
most pressure. A comparison invites "just subtract the two columns", and the
answer is that the difference is `spread`, which the backend computed.

## 2. Scope

**In**

- `app/lib/components/scenario_comparison/` — twelve files: the `ViewComponent`
  and its `register`, the model, the card, the subject strip, the header row,
  the table, the shared track row, the footer, the header-border painter, and
  the measured tokens and layout. Why twelve and not one: OD-8.
- Tests under `app/test/components/scenario_comparison/`, including the grid
  geometry asserted against the catalog mock's rendered DOM, and two goldens.
- The regenerated `component_manifest.g.dart`.

**Out**

- **The recommendation affordance.** No `recommended` badge, no "best on that
  row" emphasis, no `betterWhen` arrows. See **OD-3** — this is the spec's
  central ruling, not an omission.
- **Any chart.** This card is a table; `packages/finance_charts` is not used
  and no raw `*.amount` member is read. The "do not add geometry you do not
  need" half of GGU-55's legacy.
- **Interaction.** The catalog declares no actions for this view
  (`"actions": []`), so there is nothing to dispatch and no tap surface.
- **The lot ids and lot counts** the payload carries. See OD-6.

## 3. What was measured, and how

Every value below was read from the exported design page
`Catalog - Scenario Comparison.html`, served over HTTP and inspected with
`getComputedStyle` on the **rendered DOM** — not from the bundle's source and
not from a thumbnail. GGU-55 found two of five circulated colour values wrong
for exactly that reason, so this table is the primary artefact and
`scenario_comparison_tokens_test.dart` pins all eight colours.

| Token | Light | Dark | Where it lives |
|---|---|---|---|
| card surface | `#FDFBFF` | `#15161C` | `ChartPalette.surface` (already measured, GGU-55) |
| card hairline | `#EAE7F0` | `#24252D` | `ChartPalette.border` |
| primary text (title, figures, column head) | `#1A1B20` | `#E5E1E9` | `ChartPalette.title` |
| eyebrow / caption | `#8A8D96` | `#8A8D96` | `ScenarioComparisonTokens.caption` |
| metric name | `#44464E` | `#C9CBD4` | `.metricLabel` |
| row rule | `#F0EDF5` | `#202128` | `.rowRule` |
| column-header hairline | `#EAE7F0` | `#2A2B33` | `.headerBorder` |

The metric-name value is cross-confirmed: the catalog index's shared token
legend draws `Short-term` / `Long-term` in the same two colours.

**Geometry**, at the design's 1024 artboard:

| Measurement | Design (DOM) |
|---|---|
| card outer width | 571.367 px |
| card padding / border | `16px 18px 15px` / 1 px |
| card content box | 533.367 px |
| grid, 2 scenarios | `1.35fr 1fr 1fr`, gap 8 → 208.484 / 154.438 / 154.445 |
| grid, 3 scenarios | `1.2fr 1fr 1fr 1fr`, gap 8 → 145.531 / 121.273 / 121.281 / 121.281 |
| column header | pad `8px 10px`, radius `10px 10px 0 0`, border top+sides only |
| metric row | border-top 1 px, pad `2px 0`; name cell `9px 2px`; figure cell `9px 10px`, radius 8 |
| type | caption 10/600/0.08em · column head 12.5/500 · column label 10/400 · metric 12/400 · figure 13.5/400 |

`scenario_comparison_geometry_test.dart` asserts the laid-out tracks against
the first two rows of that table to **0.1 px**.

### Re-verified against the newer mock

A fuller catalog mock (fourteen screens, `.design-refs/`) landed after this
card was built. **It is not a design export**, which this section called it
until 2026-09-28: those files were generated on this side and handed to the
designer as a starting point (Miriam). The authority is her Figma; see
`frontend/0031` § 2 and `frontend/0033`. `Catalog_ScenarioComparison.dc.html` was re-measured the same
way, in both artboards, and **every value above is unchanged** — card surface,
hairline, padding, radius and 571.367 px width; the row rule; the eyebrow; the
metric name; the figure; both column-header lines; and the grid rules, which
are byte-identical (`.cmp2 { 1.35fr 1fr 1fr }`, `.cmp3 { 1.2fr 1fr 1fr 1fr }`,
`gap: 8px`).

**One real miss it caught.** The `Metric` caption is weight **500 with normal
tracking** in both exports and both artboards; this card was drawing it with
the eyebrow style (600 at `0.08em`). Fixed —
`ScenarioComparisonText.metricHeading` is now its own slot, asserted against
`caption`'s weight so the two cannot silently converge again.

**How it was rendered, because it matters.** Opened from `file://` inside the
worktree the page renders its chrome but **does not boot its data binding** —
the table shows `{{ h.label }}` / `{{ r.label }}` placeholders. Measured over
`http://` the same file boots fully (547 nodes, no placeholders, real
figures). Every number in this spec is from the booted render; nothing here
was measured off a placeholder.

**One finding worth keeping.** The design is CSS `box-sizing: border-box`, so
its 1 px border sits *inside* the declared width. Flutter inverts that:
`DecoratedBox` and `CustomPaint` paint over the child and reserve no space.
The same padding therefore left the content box 2 px wide — 209.30 / 155.03
against the design's 208.48 / 154.44 — until every bordered element was padded
by `ScenarioComparisonLayout.hairline` as well. The geometry test is what said
so; no golden of an all-text card would have.

## 4. Data model & migration

None. The client stores nothing.

## 5. Security notes

No new surface. The component is a pure function of a `ViewPayload`: no I/O,
no clock, no repository. Every payload path is a **string literal**, so
`binding_rules_test.dart::payload paths are literals, never variables` holds
(N-5, a security rule — an interpreter over server input is an injection
surface). No number mechanism is introduced and the geometry seam is not
widened: this card reads no raw member at all.

## 6. Acceptance criteria

1. **AC-1** — The component registers itself from its own module and reaches
   the screen with **no hand-written file edited**; only the generated
   manifest changes. *(ADR-L D-3)*
2. **AC-2** — `viewId` and `a2uiComponent` match the backend's generated
   snapshot; the component name is `ScenarioComparison`, not the index's stale
   `ComparisonCard`. *(GGU-53's defect class)*
3. **AC-3** — The subject is rendered once, above the table, and cannot vary
   per column, because the model has no field for it. *(mirrors `backend/0017`
   AC-2)*
4. **AC-4** — Every figure on screen is a `*.display` string rendered verbatim,
   and **no** raw `amount` reaches a `Text`. *(N-1, N-4)*
5. **AC-5** — Columns render in arrival order and are never sorted, filtered or
   re-ranked. *(N-10, `backend/0017` AC-6)*
6. **AC-6** — The card **names no winner**: no `recommended` badge, no
   per-row emphasis, no `betterWhen` arrow, no client-side comparison of two
   figures. *(OD-3, `backend/0017` OD-4)*
7. **AC-7** — `spread` is rendered from the backend's own figure and tokens;
   when the methods coincide the card says so and names neither end. *(N-2)*
8. **AC-8** — Every note is rendered verbatim and none is dropped. *(N-9)*
9. **AC-9** — A missing field raises `PayloadContractException` naming the
   path, which `ComponentHost` shows, rather than being reconstructed. *(N-3)*
10. **AC-10** — The laid-out grid matches the catalog mock's rendered DOM to
    0.1 px on **both** artboards, and the measured colours are pinned.

## 7. Test plan

Nine files under `app/test/components/scenario_comparison/`, split by concern
to stay inside the 150-line budget, plus `scenario_comparison_harness.dart`,
which reads the backend's generated snapshot rather than copying it.

| AC | Test |
|---|---|
| AC-1 | `_component_test.dart::register adds exactly this component to a registry`; `make manifest-check`; the package-wide `app_router_test.dart::every registered component is reachable from the route` |
| AC-2 | `_component_test.dart::serves the view id and component name the catalog publishes`; the package-wide `catalog_contract_test.dart` |
| AC-3 | `_card_test.dart::states the sale once, as caption and figure` |
| AC-4 | `_card_test.dart::puts every display string on screen verbatim` **and** `::never puts a raw figure on screen` |
| AC-5 | `_component_test.dart::keeps the columns in the order the backend sent them` |
| AC-6 | `_card_test.dart::names no winner anywhere on the card` |
| AC-7 | `_footer_test.dart::reports the spread and names both ends`, `::names neither end when the methods coincide`, `::shows the one end the backend named, and no tie line`; `_component_test.dart::names any end the backend named, not only both of them` |
| AC-8 | `_footer_test.dart::renders every note verbatim and drops none`, `::shows no note when the backend attached none` |
| AC-9 | `_component_test.dart::raises the missing field instead of reconstructing it` |
| AC-10 | `_geometry_test.dart` (four tests, 0.1 px), `_tokens_test.dart`, `_layout_test.dart`, and two goldens |

**Mutation checks**, because a green check is evidence only if it could have
been red:

| Mutation | Result |
|---|---|
| `metricFlex(2)` 135 → 120 | 2 red: the two-scenario track reads 194.01 against the design's 208.48 |
| `headerCellRadius` 10 → 6 | 3 red: both goldens (5.00 % of pixels) and the constant |
| the hairline inset removed | found in development: content box 535.367 against 533.367 |
| `namesAnyEnd` `\|\|` → `&&` | **2 red**: the one-end payload loses a name the backend sent *and* gains a tie line. Added after review — the first cut of this rule was `&&` and no test could tell the two apart |

## 8. Open decisions

**OD-1 — The metric row names are client copy, and that is a contract gap.**
The design drives its rows from a server-sent `metrics[]` list, each with a
`label`. `scenario.comparison.v1` has no such list: it carries four fixed,
named members per column (`cost_basis`, `realized_pl`, `short_term_pl`,
`long_term_pl`). So `Cost basis`, `Realized P/L`, `Short-term` and `Long-term`
are written in `scenario_comparison_component.dart`, beside the four paths
they title.

This is defensible — they are structural names for fixed fields, not data —
but it is still a string on screen that no backend wrote, and it will not
localise with the rest of the payload. **Default:** keep the client copy.
**Raise with backend** whether the projection should carry row labels the way
it carries `columns[].label`. *Owner: Lautaro.*

**OD-2 — `spread.differs` is not read; the two ends' presence is. This is a
deferral, not a prohibition.**
`ViewPayload` exposes `text`, `optionalText`, `rows` and `geometry` — and no
boolean accessor. Reading the contract's `differs` flag means adding one.

**That is allowed, and an earlier draft of this spec wrongly said ADR-L D-3
forbade it.** D-3's subject is *dispatch* — "no enum, no union, no `if/elif`,
no shared list" — and `ViewPayload.flag(path)` is none of those: it is an
additive accessor beside `optionalText` that does not grow by one entry per
component. The repository's own precedent points the same way, because
`geometry` was added to `ViewPayload` by GGU-55 and argued as an **ADR-L D-14
amendment** rather than rejected as a seam break. What is true is narrower: a
new reader on a shared type deserves a PR that can weigh it for every caller
and amend ADR-L, not a line added in passing by a feature.

So the card reads the ends, and **the rule is `||`, not `&&`**: each end that
is present is shown, and the "methods coincide" line appears only when neither
is. `spread.highest` and `spread.lowest` are `default null`
**independently** and neither is tied to `differs`, so a payload naming one
end is permitted — under `&&` the card would have dropped a name the backend
sent *and* claimed the methods coincide, two wrong statements from one missing
field. `ScenarioSpread.namesAnyEnd` is that predicate, spelled once and used
by the footer.

Three tests hold it: the published example is checked against the flag it
actually carries, `::names any end the backend named, not only both of them`
is the one that distinguishes `||` from `&&`, and the footer asserts the
rendering of the asymmetric case.

**Default:** keep the derivation. **Follow-up:** add `ViewPayload.flag(path)`
when a second component wants a boolean. *Owner: Lautaro.*

**OD-3 — There is no recommended column, and the design asked for one.**

This is the spec's central divergence and it is deliberate.

The design's schema declares `scenarios[].recommended: boolean` and
`metrics[].betterWhen: "higher" | "lower"`, and its artboards use both: one
column wears a `★ Recommended` pill and tinted header (`#EEF0FF` / `#CDD2FF`),
and the better cell of every row is tinted green (`#E3F3EC` / `#BFE4D1`) with
a tick and a legend reading *"= best on that row"*. Its prompt fragment tells
the model to "mark at most one scenario `recommended`".

**The card ships none of it**, for a reason that is not process:

- Spec `backend/0017` OD-4 rules it out, and the backend does not emit either
  field — so rendering them would mean the client inventing them.
- A component that marks one disposal strategy "recommended" is giving
  investment and tax advice. Whether FIFO's `+$3,825.00` (all long-term) beats
  LIFO's `+$1,305.00` (all short-term) depends on a marginal rate, carried-
  forward losses, a jurisdiction and intentions for the rest of the year —
  none of which this system knows or should ask for. A larger realised gain is
  not even reliably the better outcome.
- Even `betterWhen` alone is not neutral: "lower is better ▼" on *Est. tax* is
  an arrow pointing at an answer, and it is what drives the green emphasis.

What the card **does** render is `spread` — the arithmetic difference between
the extremes and which method sits at each end — because that names data the
columns already show, and the backend's own `Not advice` note is rendered
verbatim directly beneath it, so the silence is legible rather than merely
absent.

**Default:** no recommendation affordance, in this or any later revision of
this card. **If design wants to reopen it**, the conversation is with
compliance first and the backend second; the client is the wrong place to
settle it. *Owner: Lautaro + design (GGU-42).*

**OD-4 — The design has no title slot and the contract requires a title.**
The design's preview card opens with an eyebrow (*"default · sell 200 NVDA ·
2 strategies"*) and the "best on that row" legend. Both are gallery chrome:
the sibling cards in the same artboard read *"3-scenario variant"* and
*"loading · skeleton columns"* in the same slot. Meanwhile `title` is
**required** by the contract, so dropping it is not available.

The card therefore draws `title` in the caption type
`AttributionWaterfallCard` already uses, with `subject.label` opposite it, and
renders the sale as four caption/value facts underneath rather than as one
uppercased mono line. The second half matters: the eyebrow's uppercase is a
CSS `text-transform`, and `toUpperCase()` on `subject.symbol` or
`subject.label` would be the client altering a string the backend wrote.
**Default:** as built. **Raise with design** whether the card should have a
title slot of its own. *Owner: design (GGU-42).*

**OD-5 — Roboto Mono is not bundled; `tabularFigures` is used instead.**
Identical to the decision `ChartText` records for GGU-55: the design sets the
eyebrow and every figure in Roboto Mono, the app bundles no font asset, and
the reason a designer reaches for a mono face in a column of figures is digit
alignment — which `FontFeature.tabularFigures()` buys from the bundled font
without a 60 kB download. **Default:** keep it. *Owner: design.*

**OD-6 — Four payload fields are deliberately unbound.**
`columns[].short_term_lots`, `columns[].long_term_lots` and `columns[].lots`
are carried by the contract and drawn by nothing. The counts are `raw`
integers with no `*Display` companion, so putting one on screen means the
client turning a number into text — the first step of N-1, on a field the
contract classifies as raw (N-4). `lots` is a list of internal lot ids
(`lot-btc-01`) that the design has no slot for and a reader has no use for.
**Default:** leave them unbound. **If design wants "1 long-term lot" on the
card**, the contract needs a display string for it — raise it (N-3).
*Owner: Lautaro.*

**OD-7 — No figure is coloured, because the contract carries no direction.**
The catalog's shared token legend has a green *Gain ▲* and a red *Loss ▼*, and
`attribution.waterfall.v1` earns them: its buckets carry a `direction` enum.
`scenario.comparison.v1` carries none. The only other way to colour
`+$3,825.00` green would be to look at the sign inside the formatted string,
which is precisely what `.claude/rules/frontend/contract-binding.md` forbids
("do not choose a colour by parsing the string"). Every figure is therefore
drawn in the primary text colour. **Default:** neutral. **Raise with backend**
whether `realized_pl` should carry a `direction`, as the waterfall's buckets
do. *Owner: Lautaro.*

**OD-8 — Twelve modules, not one, and a second file naming a `Color`.**
Two things here.

*The count.* `.claude/rules/frontend/architecture.md` §3 allows a component to
create more than one file and treats the 150-line budget as the gate and "one
file" as the preference. A table with a measured token set, a measured layout,
a transposing model, a painter and four widgets does not fit in one file, and
each of the twelve has a single responsibility. The same trade `backend/0017`
OD-8 records for the projection.

*The colours.* `frontend/CLAUDE.md` and `chart_tokens.dart` both say
`chart_tokens.dart` is **the only file in `app/lib/` naming a `Color`**. That
sentence is now false: `scenario_comparison_tokens.dart` names eight. The
alternative was to add four fields to `ChartPalette` and `ChartTokens`, which
would edit two shared hand-written files to add a component — the thing ADR-L
D-3 exists to prevent — and three of the four are not chart roles anyway (a
table's row rule, a header hairline, a caption). No test enforced the "only
file" claim, so nothing went red; it is a documentation claim that this ticket
invalidated.

**It is recorded here rather than fixed quietly, because fixing it means
editing `frontend/CLAUDE.md`, and the ticket's instruction was to report a
shared-file edit rather than make one.** It is also the move
`.claude/rules/ci-conventions.md` §4b already models, where the `client-ci`
row stayed in the table marked **no — not written yet** rather than being
deleted: *a row in that table is a claim about the repository, and a claim
gets a truth value.*

**But a false sentence in `frontend/CLAUDE.md` is a different risk class from
one in a spec**, because that file is loaded first by everyone working in
`frontend/`, and `app/lib/charts/chart_tokens.dart` still asserts the claim
unqualified — so the two files now disagree with each other as well.

**Resolved, and not by this branch — which is the point.** GGU-57's PR (#71)
adds the tax-lot table, whose own token file falsified the same sentence for
the same reason, and **it edits `frontend/CLAUDE.md` to replace the count with
a rule**. Two components reached the identical conclusion independently, from
two directions, without coordinating — that is the seam working rather than a
coincidence, and it is stronger evidence than either branch could have
produced alone.

So no ticket is needed. **Whichever of #70 and #71 merges first fixes the
sentence; the second conflicts on that one line and should take the rule
form.** The resolution is #71's; this spec records the reasoning and the
second data point, not a deferral.

Still worth doing when someone next touches it: **give the rule a test** — a
grep for `Color(0x` under `app/lib/` against an expected file set, ten lines.
The claim rotted precisely by being enforced by nothing, and replacing one
unenforced sentence with another only resets the clock. *Owner: whoever merges
second.*
