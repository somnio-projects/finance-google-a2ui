# 0005 — Payoff chart (`payoff.curve.v1` → `PayoffChart`)

- **Area:** client (`frontend/`)
- **Status:** Implemented
- **Ticket:** GGU-63 (parent GGU-20) · **Related:** ADR-L (D-13, D-14), ADR-K, ADR-E, `specs/frontend/0002-chart-primitives-and-waterfall.md`, `specs/backend/0016`, `specs/client/0003`
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

The backend publishes `payoff.curve.v1` — the profit and loss of a *proposed*
order across a bounded range of future prices — and the client has no component
for it, so the catalog entry renders as a placeholder. GGU-55 built the chart
primitives (`packages/finance_charts`) and the first chart on top of them; this
is the second, and the first to need a **continuous line** rather than bands.

## 2. Scope

**In:** a `PayoffChart` component binding `payoff.curve.v1`; a pure-Dart
`PayoffLayout` in `packages/finance_charts`; a `CustomPainter` in
`app/lib/charts/`; the card, the totals row, the annotations and the
disclosure; goldens in both themes; phone and desktop width tests.

**Out:** the break-even and "current" **markers** and the vertical gain/loss
columns the design draws — blocked by OD-1, below. The comparison state (two
series side by side) belongs to `scenario.comparison.v1`/GGU-59. The loading
skeleton is a transport state and lives in bloc state, never in a payload
(`contract-binding.md` §3). `onPointHover` is not in the contract's `actions`.

## 3. Contract bound

From `docs/catalog/view-catalog.snapshot.json`, entry `PayoffChart`, digest
`6a69670692d0`. Paths read, all as literals:

| Path | Use |
|---|---|
| `title` | card title, verbatim |
| `disclosure` | rendered verbatim, never dropped (N-9) |
| `totals[].label`, `totals[].amount.display` | the totals row, verbatim |
| `series[].name` | series label, verbatim |
| `series[].points[].at.amount` | **geometry only** — x position |
| `series[].points[].value.amount` | **geometry only** — y position |
| `series[].points[].label` | the x tick, drawn verbatim |
| `series[].points[].value.display` | **not bound** — deferred with the hover state the contract has no action for (§2, OD-7) |
| `annotations[].label`, `annotations[].text` | annotation chips, verbatim |

`actions` is `[]`, so the component dispatches nothing.

## 4. Design

Measured from `.design-refs/Catalog_RiskPayoffChart.dc.html` — not from the
rendered DOM but from the page's own `<script type="text/x-dc">` source and its
SVG template, which carry the scales as arithmetic and so are exact rather than
sampled. The page rendered fully populated (real figures such as `+$5,880`, not
`{{ }}` placeholders); the sibling `Catalog_OrderTicket` page did show
placeholders, which is why this is stated.

Plot box `x ∈ [44, 486]`, `y ∈ [18, 244]` in a `0 0 500 280` viewBox — i.e. a
left gutter of 44 for the value labels, 14 of right padding, 18 of headroom and
36 below the plot for the tick row, which sits at `y = 262`.

| Element | Light | Dark | Geometry |
|---|---|---|---|
| Loss region | `#C0362C` @ .07 | `#FF6B5E` @ .10 | full plot height |
| Gain region | `#12805C` @ .07 | `#4ADE9E` @ .10 | full plot height |
| Grid line | `#EAE7F0` | `#24252D` | 1 px, 5 lines |
| Zero baseline | `#B8BCC6` | `#3A3B44` | **1.5 px** |
| Break-even rule | `#C07A10` | `#FFBF5C` | 1.2 px, dash `4 3` |
| Curve | `#4F5DFF` | `#7A83FF` | **2.6 px**, round cap + join |
| Second series | `#0F9D8F` | `#5FD6C8` | 2.6 px, drawn *under* the first |
| Current marker | curve colour | curve colour | r 5, halo = surface, 2.5 px |
| Axis labels | `#9A9BA4` | `#7F828C` | 9 px, 7 x-ticks, 5 y-ticks |
| Card | surface `#FDFBFF` / `#15161C`, border 1 px, radius **16**, padding **18/16/18/14** |

Four of these are already `ChartPalette` roles and match **exactly**: the curve
is `barTotal`, the grid is `border`, the marker halo is `surface`, and the two
region hues are `barLoss`/`barGain`.

`PayoffPalette` therefore carries five fields, of which only **three are new
colours** — `breakEven`, `zeroBaseline`, `axisLabel`. The other two,
`lossRegion` and `gainRegion`, are `barLoss`/`barGain` **derived** at the
artboard's wash alpha. They are fields rather than an alpha applied at the
point of use because the alpha is the one value the two artboards do *not*
share (.07 light, .10 dark) and a widget choosing between them would be
branching on brightness; they are derived rather than written out because a
transcribed hex agrees with its source only until somebody edits one, and
`payoff_palette_test.dart` asserts the channels match. The second series
colour is deferred with the comparison state.

## 5. Acceptance criteria

1. **AC-1** — the curve is plotted from `series[].points[].at.amount` and
   `…value.amount` through `ViewPayload.geometry`, and every string on screen
   is a `*.display`/`label`/`text` member drawn verbatim. *(ticket AC-1)*
2. **AC-2** — no figure is computed, formatted, summed or re-signed in `lib/`:
   `binding_rules_test.dart` stays green, and a test asserts the raw decimals
   (`"0E-30"`, `"-150.0000000000000000000000000"`) never reach the tree (N-4).
3. **AC-3** — the gain and loss regions are shaded from the **value axis
   zero**, a constant of the scale, and the zero baseline is drawn at it.
   Nothing locates a zero *crossing*. *(ticket AC-5; ticket AC-2 → OD-1)*
4. **AC-4** — `totals`, `annotations` and `disclosure` render verbatim and in
   arrival order; none is dropped, re-ordered or matched on by label (N-5,
   N-9, N-10).
5. **AC-5** — a payload whose `series` is empty, or whose `points` is empty,
   renders the card and its text without throwing; a payload missing a bound
   path raises `PayloadContractException` naming that path. *(ticket AC-4)*
6. **AC-6** — the chart lays out at 360 px and at 1024 px logical width with
   no overflow, through `LayoutBuilder` and no breakpoint.
7. **AC-7** — `PayoffLayout` is pure Dart, asserted arithmetically against the
   design's scales; goldens cover light and dark at 1.5 % tolerance.
8. **AC-8** — the component self-registers; `make manifest` is re-run and the
   generated manifest committed. Adding it edits no hand-written registry.

## 6. Test plan

| AC | Tests |
|---|---|
| AC-1 | `payoff_chart_component_test.dart` (binding), `payoff_layout_test.dart` |
| AC-2 | `binding_rules_test.dart`, `…_component_test.dart::raw values never render` |
| AC-3 | `payoff_layout_test.dart::puts zero on the value scale, not at a crossing in the data` (+ the two `zeroInDomain` cases), `payoff_painter_test.dart` |
| AC-4 | `payoff_chart_card_test.dart` |
| AC-5 | `payoff_chart_component_test.dart` (empty + contract-violation paths) |
| AC-6 | `payoff_chart_card_test.dart::lays out at phone width (…desktop width) without overflowing`, `payoff_painter_test.dart::drops a tick that would collide or overflow` |
| AC-7 | `payoff_layout_test.dart`, `payoff_chart_golden_test.dart` |
| AC-8 | `component_manifest_test.dart`, `catalog_contract_test.dart` |

Mutation check required: yes — remove `register(...)` and show the suite red.

## 7. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | **The payload cannot say where break-even is.** `totals[]` is `{label, amount}` with no key or discriminator, so the only ways to find the break-even are matching the string `"Break-even price"` (N-5 — the client interpreting a server string, and wrong in `es-AR`/`de-DE`, which `locale` offers) or computing the zero crossing (which the ticket's own AC-2 forbids). The design's Zone 2 schema has exactly the field that would close this: `markers: { breakEven, current }`. **Ask the backend for a machine-readable marker** — `markers.breakEven.amount` beside the existing pair, or a `key` on each total. | Backend (Mario) / TL | Ship without the vertical break-even rule and the column shading; shade from the value-axis zero (AC-3) and render "Break-even price $152.40" as text in the totals row. |
| OD-2 | Ticket AC-3 names `positionValue`, which **is not in this payload**. It lives in the agent tool row (`backend/src/app/agent/tools/payoff_rows.py`, `positionValueDisplay`), which the model reads — not in the projection the chart binds. The ticket appears to have been written against spec `backend/0014`'s tool output rather than `0016`'s projection. | TL | Treat the ticket AC as satisfied in principle — the component renders only what the payload carries and substitutes nothing — and re-point the AC at the tool ticket. |
| OD-3 | The design is an **options** payoff: NVDA with protective puts, a kinked curve floored at −$2,400, x in percent. The backend is explicitly a **linear spot** payoff over a crypto enum (`ADA…SOL`), x in price, and its disclosure says "There is no strike, no expiry, no implied volatility and no time decay behind this line." The two describe different products. | Design + TL | Bind the backend. The layout takes arbitrary points, so a kinked curve draws correctly if the domain ever grows one; the x axis is labelled from `points[].label`, which is a price. |
| OD-4 | Design calls the component `RiskPayoffChart`; the frozen catalog says `PayoffChart`. `catalog_contract_test.dart` binds the catalog. | Design | Use `PayoffChart` — the catalog is the contract the client registers against. |
| OD-5 | Design's x-axis is a **percent move** with `unit: "percent \| price"`; the contract offers only prices. A percent axis would need the backend to send the pair. | Backend | Price axis, labelled from `points[].label`. |
| OD-6 | `ChartPalette` gains three roles but is already 141 lines and the budget is 150. Adding them inline overflows it, and three sibling components are editing the same file this week. | — | A second `ThemeExtension`, `PayoffPalette`, carrying **only** the three roles `ChartPalette` lacks; it reuses `barTotal`/`barGain`/`barLoss`/`surface` rather than restating them. |
| OD-10 | The legend's `Loss` and `Gain` are **client-authored English** — the only two strings here the backend does not supply — on a view whose options schema offers `locale: en-US \| es-AR \| de-DE`. The app has no `flutter_localizations` at all and its existing chrome (`Portfolio`, `Ask the agent`) is hardcoded too, so this is app-wide rather than new. | TL | Keep them. If the backend ever labels the regions it shades, they become payload fields and the question closes with OD-1. |
| OD-7 | Design draws a "Current" dot with a P/L readout. The contract has no "current" field, for the same reason as OD-1. | Backend | Omitted; folded into OD-1's marker request. |
| OD-9 | **A second chart palette grew a shared list, which ADR-L D-3 forbids.** GGU-55 added `ChartTokens` to `app_theme.dart`'s `extensions:` and this ticket added `PayoffTokens` — a chain forming one entry at a time, with four catalog components still to come. Fixed here rather than argued: `chart_tokens.dart` exposes `chartExtensions(brightness)` and the theme spreads it, so a new palette is an edit to the file that already holds its colours and never to `AppTheme`. The list still exists, one layer down. | TL | Ship the spread. If the TL wants the seam fully generated (as the component manifest is), that is a follow-up; if the TL considers theme tokens outside D-3 altogether, **amend D-3 to say so** — the silent second instance was the defect, not the extension. |
| OD-8 | **The value axis cannot be labelled.** The design prints `$0`, `+$5k`, `+$10k`… down the left gutter. Every one of those is a *formatted* figure, and the payload carries a `*.display` string per **point**, never per axis tick — so drawing them would mean formatting in the client (N-1). The gridlines are drawn unlabelled and the 44 px gutter is dropped. | Backend | Ask for axis ticks as ADR-E pairs (`axis.value[].{amount,display}`) alongside the series, the way `points[].at` already ships. Until then the figures a reader needs are in the totals row, which is verbatim. |

## 8. Rollout

No flag, no migration. The component appears on the portfolio views screen as
soon as it registers, because the route asks the registry (GGU-79).
