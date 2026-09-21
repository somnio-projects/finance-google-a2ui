# 0023 — The catalog serves what the client must draw

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-53](https://somniosoftware.atlassian.net/browse/GGU-53) · **Related:** [GGU-42](https://somniosoftware.atlassian.net/browse/GGU-42) (numbers-from-tools), [GGU-78](https://somniosoftware.atlassian.net/browse/GGU-78) (surface actions), [GGU-92](https://somniosoftware.atlassian.net/browse/GGU-92) (actions in the snapshot) · **Supersedes:** 0021 OD-3
- **Also:** 0019 (frozen contract), 0021 (machine-readable catalog), 0022 (surface actions), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

The TL's directive:

> *"el backend siempre debería servir al flutter app el formato que él requiera
> para el gráfico — es decir que los esquemas de json deberían dar lo
> necesario"*

**The backend adapts to what the client needs to draw.** Design has now
exported four pages of the component catalog, and comparing them against what
this backend serves turns up four disagreements. Three are defects here. One
is a defect in the design, and it is the one that must not be conceded.

Spec 0021 §1 predicted the first of these in writing and shipped without
closing it, because 0021 OD-3 decided not to assert the component names.

## 2. Scope

**In**

- Reconciling the six component names against the design catalog, and a test
  comparing the four places each name is written down.
- `docs/catalog/design/README.md` — the design catalog's declarations
  transcribed as text, so the one literal in the suite that is *not* read from
  the registry can be re-verified after the exported HTML is gone (OD-7).
- `presentation/published.py` — `component_of` / `guidance_of`, the two
  derived facts every rendering needs.
- `presentation/guidance.py` + three `*_guidance.py` modules — the do/don't
  pair the design catalog's Zone 3 teaches the model.
- `Bucket.key` and `SeriesPoint.at` — the payload fields a painter and a tap
  need and did not have.
- Publishing the component and the guidance to the Markdown contract, the JSON
  snapshot, `GET /v1/views` and the generated prompt fragments.
- The Flutter client's `a2uiComponent` for the one component it binds today.

**Out**

- Drawing anything. The client's charting ticket consumes these values; this
  spec only guarantees they are there.
- Guidance for the three components whose design page was not exported (§4).
- Promoting `TaxLotRow.units` / `ScenarioSubject.quantity_display` to ADR-E
  pairs (§6, OD-4).

## 3. The component name — the decision

The component name is the **single string the Flutter client registers a
widget under**, so it must have exactly one value. The design catalog gives
some components three.

| Design page says | Where |
|---|---|
| `AttributionWaterfall` | waterfall Zone 2 schema · breadcrumb · prompt fragment |
| `WaterfallChart` | waterfall page badge · gallery index card |
| `ScenarioComparison` | scenario Zone 2 schema · breadcrumb · prompt fragment |
| `ComparisonCard` | gallery index card |
| `AllocationSummary` | gallery index card |
| `HoldingsSummary` | a sentence on the **waterfall's** prompt fragment |

**The rule adopted (AC-1):** a component is named by its **own A2UI schema
block** — the literal a client would read off a payload. Where no detail page
was exported, its own gallery card is the only declaration it has and
therefore wins. A name used for a component on *another* component's page is
never authoritative.

Result, and what changed here:

| View id | Was | Now |
|---|---|---|
| `attribution.waterfall.v1` | `WaterfallChart` | **`AttributionWaterfall`** |
| `holdings.allocation.v1` | `DonutChart` | **`AllocationSummary`** |
| `order.ticket.v1` | `OrderTicket` | `OrderTicket` |
| `payoff.curve.v1` | `LineChart` | **`PayoffChart`** |
| `scenario.comparison.v1` | `ComparisonCard` | **`ScenarioComparison`** |
| `taxlots.table.v1` | `TaxLotTable` | `TaxLotTable` |

Four moved, not the two the ticket flagged: the waterfall and the scenario
card were *also* wrong, and nobody had noticed because the name the backend
emitted matched one of the design's own spellings.

The renames also drop chart-*type* names (`DonutChart`, `LineChart`) for names
of the *question* the surface answers. That is the right direction
independently: whether allocation is drawn as a donut or a treemap is the
client's decision, and a contract that names the rendering constrains it.

## 4. Guidance — and what is deliberately absent

Zone 3 of each design page is the fragment injected into the system prompt,
and it is better than what this backend generated: ours lists what a view
shows and what options it takes, which is enough to *fill* a payload and not
enough to *choose* one. Asked why a number moved, a model picks between two
views that both describe "the portfolio".

`Guidance` is a bounded `use_when` / `avoid_when` pair, declared by the view
and published to all five consumers.

**Only three components have one**, because only four pages were exported and
one of them is the index. `order.ticket.v1`, `payoff.curve.v1` and
`holdings.allocation.v1` carry `None`, the contract prints *"No design page
for this component yet … It is not guidance this backend may invent"*, and
the prompt omits the lines entirely. Writing a plausible sentence for them
would be indistinguishable from one a designer approved — the honesty rule the
compliance corpus follows for "planned" (AC-7).

Two edits to the designer's wording, both recorded in the module that carries
them:

- The waterfall page says *"call `compute_attribution()`"*. No such tool is
  registered here, so the sentence points at the rule instead of at a function
  that would 404. It also names `HoldingsSummary`, which is
  `holdings.allocation.v1`.
- The scenario page says to mark at most one scenario `recommended`. Spec 0017
  OD-4 decided this card ranks nothing and ships no `recommended` field, so
  the guidance teaches the rule the payload can actually express.

## 5. The invariant that does not bend

The design's schemas type every figure as a bare `number` — `"value": number`,
`"start": {"label": string, "value": number}` — and its previews then render
`+$3,240 (+0.68%)`. Taken literally that puts the formatting in the client and
contradicts ADR-E, ADR-K D-5, GGU-42's acceptance criteria and the product's
premise.

**It is not conceded, and it does not need to be**, because ADR-K D-5 already
allows the resolution: *raw `Decimal` may accompany the string, never replace
it*. The backend ships **both**.

Auditing that promise per chart found it was **not true for the payoff curve**:

```python
SeriesPoint(label=price(point.price, shape).display,   # "$142.50"
            value=amount(point.profit_loss, shape))    # {amount, display}
```

The y coordinate was an ADR-E pair; the x coordinate was a **formatted string
and nothing else**. The curve could be labelled but not plotted — a client
would have had to parse `"$142.50"` back into a number, which is exactly the
client-side arithmetic the rule forbids. `SeriesPoint.at` is the missing pair
(AC-11).

The other charts already carried their geometry and are now asserted to:
the waterfall's running totals close arithmetically from `start` through every
`cumulative` to `end` (AC-12), and the donut's weights sweep the full circle
(AC-13).

## 6. Events

The design declares `"events": ["onSegmentTap(key)"]` on the waterfall,
sending the tapped contribution's `key`. GGU-78 implemented the affordance as
`drill.attribution.v1`, whose one argument `driver` is bounded to the curated
market reference.

They could not have agreed: **`Bucket` had no `key`**, only a prose `label`
(*"Bitcoin"*), while `driver` accepts symbols (*"BTC"*). The surface
advertised an action that no client could invoke from the payload it was
attached to — a published affordance with no value in common with its own
bound. `Bucket.key` carries the symbol, rides into the A2UI props, and AC-5
asserts every rendered key is a value the action accepts.

The naming is reconciled by mapping rather than renaming: the design's
`onSegmentTap(key)` **is** sending `drill.attribution.v1` with
`driver = <bucket.key>`. The action id stays versioned and registry-backed;
`key` is the payload field the design names.

## 6b. Data model, migration and security

**None of each, and the absence is the point.** This ticket changes only the
`presentation/` layer and the two generated artefacts: no table, no column, no
Alembic revision, no new route, no change to authentication, authorisation,
audit or logging. `GET /v1/views` gains three documented fields and keeps the
same bearer-token requirement and the same feature gate; the catalog describes
shapes, never portfolio data. Nothing added here is written to a log or an
error body.

The one thing worth naming under security is what `Guidance` is **not**: it is
declared server-side, bounded, and never read from client or model input. It
is prompt text the backend chooses, so it cannot become an injection surface
the way a free-form template would (ADR-K D-3).

## 7. Acceptance criteria

| # | Criterion | Proven by |
|---|---|---|
| AC-1 | Every projection's A2UI adapter emits the name the design catalog gives it | `test_component_names.py::test_every_projection_emits_the_component_design_named` |
| AC-2 | The JSON snapshot names the same component | `…::test_the_snapshot_names_the_component_design_named` |
| AC-3 | The Markdown contract names it, in the section **and** the index table | `…::test_the_markdown_contract_names_the_component_design_named` |
| AC-4 | `GET /v1/views` names it | `…::test_the_views_catalog_names_the_component_design_named` |
| AC-5 | Every rendered waterfall segment carries a key the drill action accepts | `test_waterfall_events.py` |
| AC-6 | The action's published choices are the values it enforces | `…::test_the_declared_action_publishes_the_same_bound_it_enforces` |
| AC-7 | Guidance is published for exactly the views design wrote one for | `test_guidance.py::test_exactly_the_views_with_a_design_page_carry_guidance` |
| AC-8 | One derivation of guidance serves every rendering | `…::test_guidance_of_serialises_the_pair_and_reports_its_absence` |
| AC-9 | The prompt teaches the do/don't pair | `…::test_the_prompt_teaches_the_pair_for_a_designed_view` |
| AC-10 | The contract prints the pair, or names the gap | `…::test_the_contract_prints_the_pair_or_names_the_gap` |
| AC-11 | The payoff curve ships both coordinates of every point, ordered and spanning a range | `test_chart_geometry.py` |
| AC-12 | The waterfall's raw running totals close from `start` to `end` | `…::test_the_waterfall_ships_the_running_totals_its_connectors_need` |
| AC-13 | The allocation's raw weights sweep the whole circle | `…::test_the_allocation_ships_the_exact_weights_a_donut_sweeps` |

## 8. Test plan

Unit only — nothing here touches the database or the network. The four-way
comparison is a **cross-declaration test** under
`.claude/rules/backend/testing.md`: the property spans the design catalog, the
adapter, the snapshot and the Markdown, so a test compares them instead of a
reviewer.

Each new file carries an **anti-vacuity** assertion, because the defects this
spec closes were all invisible to green gates:

- `DESIGN_CATALOG` must cover every registered view, so a seventh projection
  cannot slip past unnamed.
- The Markdown regex must match once per component, so a regex that stopped
  matching cannot make `sorted() == sorted()` compare two empty lists.
- The waterfall key check asserts the walk is non-empty before asserting the
  subset.
- The prompt check **counts** the pairs rather than merely finding one.

Mutation-checked. Renaming one adapter back to its old name turns **AC-1 and
AC-4** red — and deliberately *not* AC-2 and AC-3, which read the **committed**
artefacts and would still be internally consistent. That gap is closed by two
other things, and it is worth stating plainly because it is the same shape as
the defect this ticket fixes: `catalog-check` fails on the stale artefacts, and
`test_renaming_a_component_moves_both_generated_artefacts` proves a rename
really does move both renderings. Four assertions and a drift check, not four
assertions alone.

## 9. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | The design's schemas use raw numbers throughout. Concede, compromise, or refuse? | TL — **ship both, concede nothing** | ADR-K D-5 already permits the raw figure *beside* the string. The client gets everything it needs to draw and still never formats a figure a human reads. See §5. |
| OD-2 | Renaming four components breaks any consumer pinning the old strings. `/v1` is not supposed to mutate (`api-design.md`). | TL — **rename now** | The names are not yet load-bearing: one Flutter component binds one of them, in the same repository, updated in this PR. The alternative is a `/v2` for a naming error, or six months of the client registering against names design never chose. The moved digests are the announcement. |
| OD-3 | Guidance on `ProjectionSpec`, or a shared map of view id → guidance? | TL — **on the spec, defaulted `None`** | A shared map is a list of view ids in a shared file, which ADR-K D-15 forbids. Defaulting to `None` is what lets a view register without inventing guidance for itself. Three views needed a `*_guidance.py` sibling because their modules are at the 150-line budget; the prose living in one predictable file per view is a feature — a designer can edit what the model is taught without reading a projection. |
| OD-4 | `TaxLotRow.units` and `ScenarioSubject.quantity_display` are strings with no raw sibling. The design types them `number`. | TL — **leave them, and say so** | They are **table cells, printed and not plotted** — the directive is about what a painter needs, and no chart takes a lot's share as a coordinate. `QuantityDisplay` already exists in `presentation/tickets.py` and is the pair to promote into `fragments.py` the day a view actually plots units; doing it now would change a `v1` field's *type* (string → object) to serve no consumer. Recorded so the next reader knows it was considered, not missed. |
| OD-5 | Three of six components have no design page. Write guidance for them anyway? | TL — **no** | §4. `None`, and the contract says why. |
| OD-6 | 0021 OD-3 decided against asserting the component names. | TL — **reversed, see 0021 OD-3** | That reasoning assumed no source outside the backend to compare against; the design catalog is one. The inventory is the *other party* to the contract, not a copy of the registry. |
| OD-7 | `DESIGN_CATALOG` is the only inventory not derived from the registry, and it was justified by four exported HTML pages sitting in a temp directory. Commit the pages, or cite them? | TL — **transcribe the declarations, commit the transcription** | The pages are ~900 KB of JS-bundled HTML each: a binary-ish artefact that drifts silently and cannot be reviewed, which `.claude/rules/diagrams.md` refuses for exactly this reason. What the test depends on is not the bundle but *what it declares*, so `docs/catalog/design/README.md` records each page's four name slots, its Zone 3 text verbatim, and every point where the design and this backend disagree. A reader can re-verify the literal, and a reviewer can diff it. |
| OD-8 | `schemas/view_catalog.GuidanceDescriptor` duplicates `presentation.guidance.Guidance`. | TL — **duplicate it, and compare the two** | `schemas/` may not import `presentation` (`architecture.md`), and `dict[str, Any]` would publish a closed shape as an open map, generating `Map<String, dynamic>` in the client — the thing `api-design.md` §2 exists to prevent. So the shape is declared twice and `test_guidance.py` compares the field names and both bounds. Two declarations of one fact with a test between them is the pattern this whole ticket is about; two declarations with a comment between them is the defect. |

## 10. What this could not honour

- **The detail pages for `OrderTicket`, `PayoffChart` and `AllocationSummary`
  were not exported.** Their names come from the gallery index card, which is
  all the evidence there is, and they carry no guidance. If those pages carry
  a different Zone 2 schema name, `test_component_names.py` is where to change
  it — one literal, and the gate names every rendering that disagrees.
- **The design's `ScenarioComparison` wants `metrics[].betterWhen` and a
  `recommended` flag** so the client can emphasise a winning cell. Spec 0017
  OD-4 deliberately ships neither: the card names the spread and recommends
  no method. That is a live disagreement between a design page and an approved
  spec, and it needs the TL, not a unilateral change here.
- **The design's `TaxLotTable` wants `selectedLotIds`.** Our payload renders
  the lots a sale *consumes*, which is the same information arrived at from
  the other end; a selection round-trip would be a new declared option and a
  new action, i.e. its own ticket.

> **Amended 2026-09-21 by spec [0024](0024-contract-serves-the-designs.md)
> (GGU-99..GGU-104).** The three detail pages this spec records as *not
> exported* were exported later the same day. §3's rule held and did its job:
> the gallery-card fallback is a fallback, not a tie-break, so
> `AllocationSummary` → **`HoldingsSummary`** and `PayoffChart` →
> **`RiskPayoffChart`** once each component's own Zone 2 block existed.
> `OrderTicket` was already right. §4's guidance rule also held, and 0024 §5
> sharpens it: a Zone 3 fragment is prompt text, so it is audited against the
> numbers-from-tools invariant **before** it is transcribed — the `OrderTicket`
> page's, as written, instructs the reader to recompute figures.
