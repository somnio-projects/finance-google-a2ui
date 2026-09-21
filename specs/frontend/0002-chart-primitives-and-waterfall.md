# 0002 — Chart primitives and the attribution waterfall

- **Area:** frontend
- **Status:** Draft
- **Ticket:** GGU-55 · lays the foundation for GGU-57, GGU-59, GGU-61, GGU-63, GGU-65 · design GGU-42
- **Related specs / ADRs:** [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-13/D-14/D-15, [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [`frontend/0001`](0001-frontend-skeleton.md), [`client/0003`](../client/0003-client-backend-contract.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

`frontend/` renders one catalog component, and it renders it as a legend
because it cannot draw. Six of the catalog's views are charts; the showcase's
whole claim is that an agent answers a portfolio question by *composing UI*,
and a list of numbers is not that. GGU-42 has specified the first of them —
`AttributionWaterfall` — to the pixel, in light and dark.

The question this spec answers is not "which chart library" but **what a chart
is made of in a codebase where the client may not format a number**. Both
libraries proposed in Slack generate their own axis labels by formatting the
values they are handed, which breaks the product's central invariant inside a
dependency, where no gate can see it.

## 2. Scope

**In:**

- `packages/finance_charts` — a fifth, pure-Dart package: `LinearScale`,
  `BandScale`, readable tick steps, `ChartRect`/`ChartPoint`, and
  `WaterfallLayout.of(steps, width, height)`.
- `app/lib/charts/` — the `CustomPainter`, the `ChartPalette` theme extension
  and its measured `ChartTokens`, and the `WaterfallChart` widget.
- `app/lib/components/attribution_waterfall/` — the component binding
  `attribution.waterfall.v1`, its card, its header and its selection detail.
- `ViewPayload.geometry(path)` + `rawDecimal`, the single exemption to the
  numbers rule (ADR-L D-14). Not exported from the package barrel: the
  accessor is the only caller.
- `app/test/architecture/catalog_contract_test.dart`, closing `0001` OD-1:
  component tests now read `docs/catalog/view-catalog.snapshot.json` instead
  of a checked-in copy.
- Three gate repairs: `check_coverage.dart` no longer passes on an empty walk,
  `check_file_budget.dart` now scans `test/`, and `frontend/test/tool/` gives
  the gate's own scripts a suite (`make test-tool`).

**Out:**

- **Dispatching `drill.attribution.v1`.** A tap reports the bucket's `key`
  through `onSegmentTap`; carrying it to the agent is GGU-79's seam. The
  callback exists and is unwired.
- The other five charts. Each is a directory and a `make manifest`; this spec
  is the foundation that makes that true.

## 3. API contract

No HTTP surface changes. The client contract is the generated catalog entry
for `attribution.waterfall.v1` (component `AttributionWaterfall`), bound at
these paths:

| Payload path | Used for |
|---|---|
| `title` | the card's caption |
| `start.label`, `end.label`, `buckets[].label` | axis labels |
| `start.amount.display`, `end.amount.display`, `buckets[].delta.display` | the figure above each bar |
| `buckets[].cumulative.display` | the running total in the selection detail |
| `buckets[].key` | the argument a drill-down action takes |
| `buckets[].direction` | which mark a bar is drawn with — **never** the sign of a figure |
| `start.amount.amount`, `end.amount.amount`, `buckets[].cumulative.amount` | **geometry only**, through `ViewPayload.geometry` |
| `annotations[].label`, `annotations[].text` | chips beside the title, all of them, verbatim |

## 4. Data model & migration

None. The client has no persistence.

## 5. Security notes

Unchanged. One mechanism is new and is a security-relevant relaxation, so it
is recorded here as well as in ADR-L D-14: `raw_decimal.dart` is the only file
in the workspace permitted a string-to-number conversion, allow-listed **by
path** in `binding_rules_test.dart`. It is not an interpreter — it reads a
decimal the backend wrote and produces a canvas coordinate — and N-5's ban on
evaluating server-supplied strings is untouched. `binding_rules_test.dart`
also now covers `payload.geometry(…)` in the literal-path rule, so a field
path still cannot be chosen at runtime.

## 6. Acceptance criteria

1. **AC-1** — Every bar of the design's reference walk lands within 0.1 px of
   the measured artboard, in both top edge and height, at the artboard's
   533.37 × 200 plot.
2. **AC-2** — Bar width is `min(0.62 × band, 44 px)`, matching both artboards
   (44.0 px at a 76.20 px band, 21.7 px at 34.96 px).
3. **AC-3** — The value axis is the walk's extent rounded outwards to a
   readable step; for the reference data that is 478,000 → 484,000.
4. **AC-4** — A connector runs horizontally from each band's centre to the
   next, at the running total the step it follows arrived at.
5. **AC-5** — Light and dark are the measured palettes, and geometry is
   identical between them.
6. **AC-6** — Every figure on screen is a `*.display` string; no raw decimal
   appears anywhere in the rendered tree.
7. **AC-7** — A bar's mark comes from `buckets[].direction`; an undeclared
   value raises `PayloadContractException` naming the path.
8. **AC-8** — Tapping a band reports that bucket's `key`; a total reports
   nothing.
9. **AC-9** — All annotations render, in arrival order, verbatim.
10. **AC-10** — Adding the next *component* edits no hand-written file: a
    directory plus `make manifest`. This is the component seam only. The
    chart **palette** is a shared enumeration by design — a chart type
    needing a role the ten current ones do not cover (a line stroke, a donut
    track) adds a field to `ChartPalette` and `ChartTokens`, which is an edit
    to two shared files and is accepted (ADR-L D-13).
11. **AC-11** — Every registered component's view id and A2UI component name
    are ones `view-catalog.snapshot.json` publishes.
12. **AC-12** — `check_coverage.dart` exits non-zero when its walk finds no
    `lib/` sources.
13. **AC-13** — `cd frontend && make gate` is green, at 100 % line coverage
    per file across all five packages.

## 7. Test plan

| AC | Test |
|---|---|
| AC-1 | `packages/finance_charts/test/src/waterfall_layout_test.dart::places every bar where the design draws it` (14 assertions against `design_reference.dart`) |
| AC-2 | `…/band_scale_test.dart::widens a bar with its band until the cap` |
| AC-3 | `…/tick_steps_test.dart::recovers the reference waterfall axis from the design`, `…/linear_scale_test.dart::defaults to the interval count the reference design uses` |
| AC-4 | `…/waterfall_layout_test.dart::runs one connector between each pair of neighbours` |
| AC-5 | `app/test/charts/chart_palette_test.dart`, plus the light and dark goldens. The goldens capture the **chart**, not the card: whole-card goldens drifted 0.54–0.70 % across platforms against a 1.26 % smallest-defect signal, and goldening the chart instead moves the signal to 5–7 % (ADR-L D-15) |
| AC-6 | `…/attribution_waterfall_card_test.dart::never shows a raw decimal`, `…/waterfall_chart_test.dart::never puts a raw figure on screen` |
| AC-7 | `…/attribution_waterfall_component_test.dart::takes each bar direction from the backend enum, not a sign` and `::raises a direction the contract does not declare` |
| AC-8 | `…/attribution_waterfall_card_test.dart::reveals the tapped bucket and reports its key`, `::a total is not drillable` |
| AC-9 | `…/attribution_waterfall_detail_test.dart::renders every annotation as one chip, label and text` |
| AC-10 | `app/test/architecture/component_manifest_test.dart` (unchanged, and it passed with the new directory) |
| AC-11 | `app/test/architecture/catalog_contract_test.dart` |
| AC-12 | `frontend/test/tool/check_coverage_exit_test.dart::fails when the walk finds no lib/ sources` — the script is spawned and its **exit code** asserted, because the empty map was only the precondition. Mutation-checked by deleting the guard |
| AC-13 | `make gate` |

**Mutation checks required: yes**, and performed:

| Rule | Mutation | Result |
|---|---|---|
| The value scale | `LinearScale.defaultTargetCount` 2 → 5 | 3 geometry **tests** (14 assertions: 7 bar tops + 7 heights) **and** all 3 goldens red; both green again on revert |
| The geometry seam's narrowness | `double.tryParse` moved into `view_payload.dart` | `binding rules::nothing formats or computes a number` red. The seam's *size* is asserted directly by `::the geometry seam is the only exemption`, and the function is not exported from the package barrel, so `ViewPayload.geometry` is its only caller |
| The empty-walk guard | the guard deleted from `check_coverage.dart` | `check_coverage exit codes::fails when the walk finds no lib/ sources` red; before the fix the script printed `coverage ok — 0 lib file(s) accounted for` and exited 0 |

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | ~~`app_router.dart:38` hard-codes the view id, so this component would be registered, covered and **invisible**.~~ **Closed by GGU-69 (`dd03b49`) while this branch was open**: the route carries no ids at all — `PortfolioViewsPage` reads them from the registry, so a registered component is reachable *by construction*, and `app_router_test.dart::every registered component is reachable from the route` holds it. This branch was rebuilt on that and adds the other half, `catalog_contract_test.dart` (registry ⊆ the backend's published catalog). Nothing here edits the router. | — | closed |
| OD-2 | The design's net pill is green and signed. `annotations[]` carries only `label` and `text` — nothing says which annotation is the net or which way it points. Add `annotations[].direction` (and perhaps `role`) to the projection? | backend + design | chips stay neutral; the figure is still shown verbatim |
| OD-3 | The design's selected tooltip shows `+4.2% · 90 sh · $1,204.66`. No such fields exist in `attribution.waterfall.v1`. Extend the projection, or accept the three fields it has? | design + backend | the detail strip shows label, contribution and running total |
| OD-4 | The design sets chart type in Roboto Mono; the app bundles no font. `tabularFigures` buys the digit alignment without a 60 kB download. Ship the font? | design | keep `tabularFigures` on the bundled face |
| OD-5 | ~~`maxViewsPerRequest` is 4 and the catalog has six components, so the fifth surface is rejected before a round trip.~~ **Closed by GGU-69**: `views_batch.dart` chunks the ids and the page issues one request per chunk, which the reachability test exercises. Worth re-reading when a sixth component lands, because the cost is now round trips rather than a failure. | — | closed |
| OD-6 | CSS leaves a `dashed` border's pattern to the user agent, so the connector's dash could not be measured. 4 on / 3 off matches Chrome at 1.5 px. | design | keep 4/3 |

## 9. Rollout & observability

No flags, no migrations. The component appears on the portfolio surface as
soon as it is registered — the route requests whatever the registry holds
(GGU-69) — so the only prerequisite is a backend that serves the view.
`flutter build web --release` stays a CI job and was run locally for this
change: `✓ Built build/web`.
