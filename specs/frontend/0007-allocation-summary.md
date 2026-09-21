# 0007 — The allocation summary draws

- **Area:** frontend
- **Status:** Draft
- **Ticket:** GGU-65 (the Flutter half of GGU-21) · builds on GGU-55
- **Related specs / ADRs:** [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-13/D-14/D-15, [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [`frontend/0002`](0002-chart-primitives-and-waterfall.md), [`client/0003`](../client/0003-client-backend-contract.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

### 1a. What already exists — measured before anything was written

`app/lib/components/holdings_allocation/` is not empty. It landed with the
skeleton (GGU-91, spec `frontend/0001`) and it is honest about what it is: the
component's own docstring said the raw members "exist for chart geometry,
which this skeleton does not draw yet", and the card's said the arc "lands
with the charting ticket … a legend that shows every figure correctly is the
honest skeleton until then". **GGU-65 is that ticket.**

Measured against the ticket's five acceptance criteria, at `c6dd5b2`:

| Ticket AC | State before this spec | Evidence |
|---|---|---|
| 1 — binds `holdings.allocation.v1`, every figure a `*Display` string | **Met.** All seven bound paths were `label`/`key`/`*.display`; the row model had no `double` on it at all | `holdings_allocation_component.dart`; `…_component_test.dart::binds every display string verbatim`, `::never puts a raw figure on screen` |
| 2 — handles no surface at all, gracefully | **Met in the code, untested.** `ConversationView` renders `AgentAnswered` independently of any surface, but **no test named the case**. The suite had `answers in an interface, not only in text` and nothing for its complement | `conversation_view_test.dart` before this PR |
| 3 — `top_n` / `other` comes from the payload | **Met structurally, partly asserted.** No fold, filter or sort exists anywhere and `binding_rules_compute_test.dart` makes the mechanisms unavailable. The card test *did* name the `other` bucket (`renders one tile per category, residual bucket included`) | `binding_rules_compute_test.dart`; the old card test |
| 4 — tests bind the catalog's example, plus the no-surface case | **Half met.** The suite bound `holdingsAllocationPayload()` — a checked-in **copy** in `test/helpers/fixtures.dart`, which `.claude/rules/frontend/testing.md` §5 says a component test must not use. The waterfall reads `exampleFor('AttributionWaterfall')`; this one did not | `fixtures.dart` vs `catalog_snapshot.dart` |
| 5 — tokens for the category colours, palette survives more categories than colours | **Not met.** There was no categorical colour in this app. `ChartPalette` carries ten *semantic* roles (gain, loss, total, connector…) and none of them is a category; nothing cycled | `chart_palette.dart`, `chart_tokens.dart` |

So two ACs were met, one met but under-asserted, one half met, one untouched.
**Everything the component did survives this spec**; what follows is added
beside it.

> A draft of this table, rescued from an interrupted earlier attempt, claimed
> "no test names the `other` bucket". That was wrong — the card test did. The
> correction is kept here rather than silently fixed, because the difference
> between AC-3 being *unasserted* and *partly asserted* is exactly the kind of
> thing a measurement is for.

### 1b. And measured against the design, which is a different question

**A design does exist**, contrary to the brief this work started from:
`.design-refs/Catalog_HoldingsSummary.dc.html` (the component) and
`.design-refs/Holdings.dc.html` (the screen). The 132-line card was written
when it was unavailable, so "does it satisfy GGU-65" and "does it match the
design" are two questions with two answers. Against the design, the card
before this PR matched **almost nothing**:

| Design element | Before |
|---|---|
| The donut itself | absent |
| Card chrome: 16 px radius, 1 px `#eae7f0` hairline, 16/18 padding | a Material `Card` with the app's default 12 px radius |
| Header: uppercase caption, 30 px headline figure, a 13 px line under it | `titleLarge` title, then a label/value row |
| Legend: 10 px swatch at 3 px radius, 10 px gap, label · weight · value | a row of label · value · weight, no swatch |
| Six-colour categorical ramp, light and dark | none |

### 1c. How the design was measured, and why the method is in this spec

**`file://` does not work, and a measurement taken there is worthless.** The
preview tool rewrites a local page to a `data:` URL, so its relative
`<script src="./support.js">` never resolves, the bindings never run, and
every value stays an unexpanded `{{ … }}`. A render taken that way reports
`mustache: 35` and colours of `none`. Inlining `support.js` into a
self-contained copy does not help either: the tool re-serves the original.

What works is **HTTP**, and only with the sandbox off for that one command —
inside it, `socket.bind` fails with `PermissionError`. Serving `.design-refs/`
with `python3 -m http.server` and loading `http://localhost:<port>/…` boots the
page (`mustache` drops 35 → 1) and `getComputedStyle` then returns real values.

Both were run here, and the live render **confirmed** a parallel reading taken
from the page source (its literal inline CSS, and the `renderVals()` block that
supplies the bound values). Two independent derivations agreeing is why the
numbers below are stated as measurements rather than as readings.

## 2. Scope

**In:**

- `packages/finance_charts` — `DonutLayout.of(weights, size)` + `DonutArc`, and `DonutHitTest` (`arcIndexAt`): pure-Dart arc geometry and hit testing, asserted arithmetically against the design's own rendered gradient stops.
- `app/lib/charts/` — `DonutPainter`, `DonutChart`, `AllocationPalette`, and the measured ramps in `chart_tokens.dart`.
- `app/lib/components/holdings_allocation/` — a model, a header, a legend, a legend row and an empty state beside the card.
- The suite moves off `fixtures.dart` onto `catalog_snapshot.dart` for this component, and gains the empty-portfolio, single-holding, residual-bucket, ramp-wrap, no-surface and two-width cases.

**Out:**

- **An action.** `AllocationSummary` declares `"actions": []` in the frozen catalog, so unlike the waterfall this component dispatches nothing. Selection is local: tapping an arc or a row highlights it and nothing leaves the widget. The design's Zone 2 *does* declare `events: ["onSliceTap(key)"]` — see OD-1.
- **The day-change column and the all-time gain.** The design draws both; the contract carries neither. See OD-1.
- **The `Holdings` screen** (its segmented By class / By sector toggle, its per-row left-border accent, its expanded row). That is a screen, not this component, and `groupBy` is not in the contract.
- The remaining four charts (GGU-57, 59, 61, 63).

## 3. Contract

No HTTP surface changes. The client binds the frozen entry for
`holdings.allocation.v1` (component `AllocationSummary`), digest `7c827ee9a8b8`:

| Payload path | Used for |
|---|---|
| `title` | the card's caption, in the design's `subtag` slot |
| `total.amount.display` | the 30 px headline figure |
| `total.label` | the muted line under it |
| `categories[].label`, `categories[].key` | legend rows |
| `categories[].value.display`, `categories[].weight.display` | the two figures on a legend row |
| `categories[].weight.value` | **arc sweep only**, through `ViewPayload.geometry` (ADR-L D-14) |

`total.amount.amount` and `categories[].value.amount` stay unread: the ring is
swept from the weights, and a second raw member read for nothing would widen
the D-14 seam for no gain.

**The client computes no angle from a figure it displays and displays no
figure it computed.** `weight.value` becomes a sweep in radians and never a
string; `weight.display` becomes a string and never an angle. These are two
disjoint paths and §7 asserts both, including that a category whose *string*
differs is a different value from one whose *share* differs.

### 3a. Where the design and the frozen catalog disagree

Flagged, not resolved. The catalog is what the backend serves, so the client
binds the catalog; each row below is a question for design and backend.

| # | Design page (Zone 2) | Frozen catalog | Effect here |
|---|---|---|---|
| 1 | component `HoldingsSummary` | component **`AllocationSummary`** | client registers `AllocationSummary`; `catalog_contract_test.dart` pins **both** the name it binds and the fact that `HoldingsSummary` is absent, so reconciling them is a decision and not a silent rename |
| 2 | `totalGain: {amount, percent, period}` | absent | the design's third header line carries `total.label` instead; inventing a gain would be N-1 on fields N-3 says to raise |
| 3 | `allocation[].dayChangePct` | absent | the legend's fourth column is not drawn |
| 4 | `groupBy: assetClass \| sector` | absent (options are `sort`, `top_n`, `include_other`, `precision`, `currency`) | no toggle |
| 5 | props are raw `number`s, formatted in the page's own JS (`toLocaleString`, `toFixed`) | `*Display` strings beside raw decimals (ADR-E) | ours is right; the design page predates ADR-E. Same pixels, different provenance |
| 6 | `events: ["onSliceTap(key)"]` | `"actions": []` | selection stays local |

## 4. Structure

```
packages/finance_charts/lib/src/donut_layout.dart      DonutArc, DonutLayout.of(...)
packages/finance_charts/lib/src/donut_hit_test.dart    arcIndexAt / angleAt
app/lib/charts/donut_painter.dart                      the CustomPainter
app/lib/charts/donut_chart.dart                        the widget + the gesture
app/lib/charts/allocation_palette.dart                 the categorical ThemeExtension
app/lib/charts/chart_tokens.dart                       (edited) the measured ramps
app/lib/charts/chart_text.dart                         (edited) subtag/headline/legend styles
app/lib/components/holdings_allocation/
  holdings_allocation_component.dart                   (edited) binds weight.value
  holdings_allocation_model.dart                       AllocationCategory, AllocationData
  holdings_allocation_card.dart                        (rewritten) chrome + the two layouts
  holdings_allocation_header.dart                      the three header lines
  holdings_allocation_legend.dart                      the list
  holdings_allocation_legend_row.dart                  one row's five columns
  holdings_allocation_empty.dart                       the empty portfolio
```

`chart_tokens.dart` is edited rather than a second colour file: it is the only
file in `app/lib/` naming a `Color` and that convention is worth the diff.
`ChartPalette` is **not** edited — a categorical ramp is a different concern
from ten semantic roles, and an eleventh field on a 141-line file would have
broken the budget anyway.

**Hit testing lives in the package, not the widget**, which is a ruling this
spec makes rather than inherits: it is a pure function of an offset and a
layout (ADR-L D-13), and keeping it there is what let it be written without
`.abs()` — banned from `app/lib` with **no carve-out**, deliberately.

## 5. Security notes

Nothing changes. No new transport, no new stored value, no new string
interpreted. `geometry` is already the audited seam and this adds a second
caller of it, not a second seam. Nothing under `.design-refs/` is committed.

## 6. Acceptance criteria

Numbered to the ticket's own ACs where they correspond.

1. **AC-1** (ticket 1) — every figure on screen is a `*.display` string the backend sent, and no raw member reaches a `Text`. Holds for the headline, both legend figures, and the empty state.
2. **AC-2** (ticket 5) — category colours come from `ChartTokens`, light and dark, through `AllocationPalette`; **a payload with more categories than the ramp has colours renders every category**, colours repeating in order.
3. **AC-3** (ticket 3) — a payload whose last row is the backend's residual bucket renders it like any other row. The client contains no grouping, no `top_n` and no sort, and `binding_rules_compute_test.dart` keeps the mechanisms unavailable.
4. **AC-4** (ticket 2, payload half) — a payload with `categories: []` renders the caption, the total and a stated empty message. No donut, nothing thrown, and the card does not collapse.
5. **AC-5** (ticket 2, turn half) — a turn that produces answer text and **no** render intent shows the text alone, with no placeholder, no error and no empty card, and a test says so in those words.
6. **AC-6** (ticket 4) — the component suite binds the example read from `docs/catalog/view-catalog.snapshot.json` via `exampleFor('AllocationSummary')`, not a checked-in copy.
7. **AC-7** — the arc geometry is asserted arithmetically: sweeps reproduce the design's **rendered** `conic-gradient` stops to 0.01°, start at twelve o'clock, sum to a full turn under rescaling, and a single 100 % holding is one full arc.
8. **AC-8** — the card lays the ring beside the legend at desktop width and above it at phone width, at the design's two diameters, and a test pumps each. Goldens of the ring in light, dark and selected, at the 1.5 % tolerance `flutter_test_config.dart` already sets — unchanged by this spec.
9. **AC-9** — `cd frontend && make gate` green: format, analyze, budget, manifest-check, the five suites, and 100 % line coverage per file.

## 7. Test plan

| AC | Test |
|---|---|
| AC-1 | `holdings_allocation_component_test.dart::binds every display string verbatim`, `::never puts a raw figure on screen`, `::reads the raw weight only as geometry, never as text` |
| AC-2 | `allocation_palette_test.dart::carries the design's measured ramp, in order`, `::wraps the ramp rather than running out`; `holdings_allocation_legend_test.dart::colours every category when the ramp runs out` |
| AC-3 | `holdings_allocation_component_test.dart::renders the backend residual bucket as an ordinary row`, `::keeps the rows in the order the backend sent them` |
| AC-4 | `holdings_allocation_card_test.dart::states the empty portfolio instead of drawing a ring` |
| AC-5 | `conversation_view_test.dart::shows an answer with no surface as text alone` |
| AC-6 | `holdings_allocation_component_test.dart` reads `CatalogSnapshot.load().exampleFor('AllocationSummary')` |
| AC-7 | `packages/finance_charts/test/src/donut_layout_design_test.dart`, `donut_layout_test.dart`, `donut_hit_test_test.dart` (`dart test`) |
| AC-8 | `holdings_allocation_card_test.dart::lays the ring beside the legend at desktop width`, `::stacks the ring above the legend at phone width`; `holdings_allocation_golden_test.dart` |
| AC-9 | `make gate` |

**Mutation checks: two, with pasted output in the PR.** The component's
`register(...)` removed, and one bound figure switched to another payload path.
The first is the more interesting result and is written up in the PR: it turns
the gate red at **`analyze`**, not at `manifest-check`, because the generator
lists *directories* under `app/lib/components/` and emits a `register` call per
directory without checking the function exists. The manifest stays
byte-identical; the workspace stops compiling. The gate catches it either way,
but not at the step the prose implies.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | **The design page and the frozen catalog disagree in six places** (§3a): the component name, the all-time gain, the per-row day change, `groupBy`, raw-vs-formatted props, and whether a slice tap dispatches. The backend's `test_component_names.py` holds design's names as a literal, so these two declarations are already meant to agree | design + backend (GGU-42, GGU-21) | Bind the catalog; draw the design's slots only where the contract fills them; leave the rest undrawn. Every gap is a backend field, not a client computation |
| OD-2 | **The two design pages use different ramps.** The component page's slots 2–4 are `#0c9d8f, #d99000, #9a5cff`; the `Holdings` screen draws the same component with `#0f9d8f, #9aa0aa, #f0a52e` — a grey in the third slot where the component page has amber | design | The component page is the contract for a component. Recorded in `chart_tokens.dart` beside the values |
| OD-3 | **The stacking breakpoint (340 px) is interpolated, not measured.** The design lays the ring beside the legend in its primary card (~400 px of content) and above it in both secondary cards (~300 px); the switch is somewhere between and no artboard pins it | design | 340, the midpoint. One constant to move |
| OD-4 | **The empty-portfolio copy is ours.** The design's third state is a loading *skeleton*, which is a different thing; it draws no empty state. `categories` carries `state: "empty"` in the catalog, so the state exists and something must be shown | design | "No holdings to allocate yet." — stated in `holdings_allocation_empty.dart` as ours rather than implied to be approved |
| OD-5 | The design sets its figures in Roboto Mono and this app bundles no mono face. `frontend/0002` already carries this for the waterfall; the allocation card inherits the same `tabularFigures` substitution | design | Keep, tracked once in `0002` |

## 9. Rollout & observability

No flag, no migration, no metric. The component is already registered and
already reachable — `PortfolioViewsPage` asks the registry and
`fetchAllPortfolioViews` chunks the request (GGU-79) — so this PR changes what
the surface *looks like*, not whether it appears.
