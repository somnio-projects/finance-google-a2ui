# 0016 — `payoff.curve.v1`: the chart under an order ticket

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-41](https://somniosoftware.atlassian.net/browse/GGU-41) · **Related:** 0005 (presentation layer), 0014 (the `payoff` tool that feeds it), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

Spec 0014 shipped `payoff`, the deterministic tool that prices a proposed order
across a bounded price range, and closed OD-7 with *"no projection renders this
— `payoff.curve.v1` is Epic 2's"*. Until it exists, the turn that answers
*"what does $500 of SOL look like if it drops 20 %?"* has a correct set of
numbers and nothing to draw them with: the registry holds a waterfall, which
splits one total into contributions, and a donut, which splits a portfolio into
weights. A payoff is a line over a price axis and is neither.

This spec adds that line. It adds no arithmetic: every figure comes from
`app.domain.payoff_pricing`, and this layer chooses a resolution and formats.

It also inherits spec 0014's honesty boundary intact. The word *payoff* invites
an options reading, and there is no strike, no expiry, no volatility and no
pricing model anywhere in this repository (0014 OD-8). A chart is a stronger
claim than a paragraph — a reader who would question a sentence accepts a
curve — so the disclosure travels **inside the payload** and the A2UI surface
binds it (OD-6).

## 2. Scope

**In**

- `app/presentation/views/payoff_curve.py` — the projection: id, DTO, pure
  `render()`, A2UI adapter, `fitness()` and its `register(...)` call.
- `app/presentation/payoff_order.py` — the declared, bounded order.
- `app/presentation/payoff_figures.py` — the one price resolution and the
  fragments the DTO is built from.
- Tests for all three.
- One row in `specs/README.md`.

**Out**

- **Any change to `fragments.py`.** The chart is built from `Series`,
  `SeriesPoint`, `Annotation`, `Total` and `MoneyDisplay` as they stand
  (ADR-K D-16). Nothing here needed a new primitive.
- **Options, Greeks, implied volatility, time decay** — 0014 OD-8, unchanged.
- **Widening `ViewQuery`** so a browser can pass an order on `?view=` (OD-7).
- **A second home for the payoff bound table** shared with the tool (OD-8).
- Any edit to another view module, to `registry.py`, to `prompt.py` or to
  `contract.py`: adding a chart edits no shared file (ADR-K D-15).

## 3. API contract

No new route. The projection is published by the registry to the four
consumers of ADR-K D-14 and served by the endpoints in
`presentation/endpoints.py`.

**Options** — all declared, bounded, defaulted, described and exemplified.
Anything else is a 422 (`extra="forbid"`), and an out-of-range value is
rejected, never clamped.

| Option | Type | Default | Notes |
|---|---|---|---|
| `symbol` | one of the eight curated tickers | `"SOL"` | A closed `Literal`, not a pattern — OD-3 |
| `size` | int, 1..1 000 000 000 | `500` | Counted in `size_in`. An integer, not a decimal string — OD-9 |
| `size_in` | `"units" \| "usd"` | `"usd"` | `usd` is divided by the entry price here, never by the model |
| `side` | `"buy" \| "sell"` | `"buy"` | `sell` is the mirror curve of a spot position, not a short (0014 OD-6) |
| `range_pct` | int, 5..90 | `30` | Half-span of the grid, as an integer percent (0014 OD-3) |
| `steps` | int, 1..25 | `12` | Per **side**; the line is `2 × steps + 1` points (0014 OD-2) |
| `currency`, `precision`, `locale` | `DisplayOptions` | `USD`, `2`, `en-US` | `precision` governs money, never a unit price — OD-4 |
| `fields` | `FieldSelection` | all | `totals`, `series`, `annotations` |

**Payload**

```jsonc
{
  "view": "payoff.curve.v1",
  "title": "Payoff across a price range: buy Solana",
  "disclosure": "Illustrative linear spot payoff … no strike, no expiry, no implied volatility and no time decay …",
  "totals": [
    { "label": "Entry price",      "amount": { "amount": "152.40", "display": "$152.40" } },
    { "label": "Break-even price", "amount": { "amount": "152.40", "display": "$152.40" } },
    { "label": "Notional",         "amount": { "amount": "499.99…", "display": "$500.00" } }
  ],
  "series": [
    { "name": "Profit / loss",
      "points": [ { "label": "$106.68", "value": { "amount": "-150.00…", "display": "-$150.00" } } ] }
  ],
  "annotations": [
    { "label": "Entry",      "text": "$152.40" },
    { "label": "Break-even", "text": "$152.40" },
    { "label": "Low",        "text": "at $106.68: -$150.00" },
    { "label": "High",       "text": "at $198.12: $150.00" }
  ]
}
```

Every figure is a `*Display` string; the exact `Decimal` rides beside it for
plotting and never instead of it (ADR-K D-5). The A2UI surface is a
`PayoffChart` binding `lines`, `totals`, `markers` and `disclosure`.

> **Amended 2026-09-21 by spec [0023](0023-catalog-serves-the-client.md)
> (GGU-53).** The component was `LineChart` until the design catalog was
> exported and the names were reconciled against it (0023 §3) — a contract
> should name the question a surface answers, not the shape it is drawn as.
> And the claim above was **not true of the x axis**: each `SeriesPoint`
> carried its price only as a formatted `label`, so the curve could be
> labelled but not plotted. `SeriesPoint.at` is the pair it was missing
> (0023 §5).

Prices are printed to the resolution **this curve** needs, once for the whole
payload — see OD-4.

## 4. Data model & migration

None. The projection is pure and the portfolio arrives as an argument.

## 5. Security notes

Read-only, no I/O, no session, no clock. Every option is declared and bounded:
the ticker is a closed `Literal` of eight values, the size is capped, and
`steps ≤ 25` with `range_pct ≤ 90` make the largest line this projection can be
made to draw **51 points**, whatever the model asks for. No free-form
expression, field path or template is ever interpreted from caller or model
input (ADR-K D-3). The subject appears in no payload.

## 6. Acceptance criteria

1. **AC-1** — The projection registers itself from its own module and reaches
   the registry, `/v1/views`, OpenAPI and the generated prompt fragments with
   no shared file edited.
2. **AC-2** — The entry price is a **sampled grid point**: the middle point of
   a `2 × steps + 1` line, where the profit is exactly `$0.00`, not
   approximately (0014 OD-2).
3. **AC-3** — A `buy` rises strictly with the price and a `sell` is its exact
   mirror; the low and high ends are equal and opposite.
4. **AC-4** — A size in `usd` resolves to `amount / entry_price`, unrounded,
   and the **displayed** notional is that amount back. A size in `units` is
   priced as given.
5. **AC-5** — Every figure the client binds is a pre-formatted string, in
   `totals`, in `series` and in `annotations`.
6. **AC-6** — The line is bounded by `steps ≤ 25` (51 points), an out-of-range
   or undeclared option is **rejected** rather than clamped or ignored, and the
   same options twice give a byte-identical payload.
7. **AC-7** — Twelve refusals are refusals: an unknown ticker, a ticker in the
   wrong case, a zero size, a size over the cap, an unknown size unit, an
   unknown side, both ends of `range_pct` and of `steps`, an out-of-range
   `precision` and an undeclared option — each raises rather than falling back
   to a default. A section this view does not offer is refused too.
8. **AC-8** — Every point of a curve is distinguishable: no two rows share a
   displayed price, including on the cheapest seeded ticker at the finest grid
   the options allow, and no price is printed two ways in one payload
   (0014 OD-10).
9. **AC-9** — The payload states what the curve is **not**: `disclosure` names
   the absence of a strike, an expiry, implied volatility and time decay, and
   the A2UI surface binds it.
10. **AC-10** — `fitness` is `0` for every portfolio, so the selection rule
    never draws this chart at a caller who did not ask for it (OD-2).

## 7. Test plan

Three files, split the way the source is: `test_payoff_curve.py` (what the
chart says), `test_payoff_curve_options.py` (what it accepts and refuses),
`test_payoff_figures.py` (how it prints).

| AC | Test |
|---|---|
| AC-1 | `test_payoff_curve_options.py::test_the_registry_discovers_it_without_a_shared_list` — the one that goes red when `register(...)` is deleted |
| AC-2 | `test_payoff_curve.py::test_the_entry_price_is_a_grid_point_where_nothing_is_made_or_lost` |
| AC-3 | `test_payoff_curve.py::test_a_buy_rises_with_the_price_and_a_sell_is_its_mirror` (parametrized over both sides) |
| AC-4 | `test_payoff_curve.py::test_a_dollar_order_is_sized_at_the_entry_price` (which asserts the product is **not** exact), `::test_a_size_in_units_is_priced_as_given` |
| AC-5 | `test_payoff_curve.py::test_every_figure_the_client_binds_is_a_preformatted_string` |
| AC-6 | `test_payoff_curve_options.py::test_the_line_is_bounded_by_the_step_limit`, `::test_the_same_options_twice_give_the_same_payload` |
| AC-7 | `test_payoff_curve_options.py::test_a_rejected_option_is_never_a_default` (twelve bad calls), `::test_a_section_this_view_does_not_offer_is_refused` |
| AC-8 | `test_payoff_figures.py::test_no_two_points_of_the_finest_curve_share_a_displayed_price`, `::test_price_places_is_the_finest_of_the_quote_and_the_grid`, `::test_a_coarse_grid_quotes_the_entry_exactly_as_price_display_would` |
| AC-9 | `test_payoff_curve.py::test_the_disclosure_refuses_the_options_reading_of_payoff`, `::test_the_surface_binds_the_line_the_markers_and_the_disclosure` |
| AC-10 | `test_payoff_curve.py::test_it_is_never_chosen_from_the_data`, `test_payoff_curve_options.py::test_the_selection_rule_never_reaches_for_it` |
| OD-3 | `test_payoff_curve_options.py::test_the_option_domain_is_exactly_the_curated_market_reference` — the ticker list cannot drift from the market reference in silence |
| OD-9 | `::test_the_generated_prompt_teaches_every_bound_truthfully` — the fragment the model is taught describes each option's real domain |
| OD-4 | `test_payoff_figures.py::test_the_requested_precision_governs_money_but_never_a_unit_price` |

Two shared assertions were updated, both of which were hand-maintained lists of
view ids inside tests whose names promise "every registered projection":
`test_registry.py::test_the_process_registry_holds_every_reference_projection`
gains the third id, and the two
`test_catalog_describes_every_registered_projection` tests (API and service)
now compare against `REGISTRY.all()` instead of a literal pair, which is what
they already zip against on the next line.

Mutation checks required: **no** by the rule — this changes no authentication,
rate limiting or error masking.

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | **What does `render()` take?** The `Projection` Protocol types it `Callable[[Portfolio, Any], ProjectionDto]`, but a payoff curve is not the portfolio. | TL — **`(Portfolio, options)`, and the seam is worth naming** | ADR-K D-6 says *"domain result + options → DTO"*; the code says `Portfolio`, in three places at once (`registry.Projection.render`, `ProjectionSpec.render`/`fitness`, and `spec.example`, which renders over `sample_portfolio()`). A projection whose input is a different domain result cannot satisfy that Protocol — `Callable` is contravariant in its arguments, so a `render(PayoffCurve, …)` fails basedpyright at `register(...)`, `example` cannot be produced, `select_view` cannot score it, and the discriminated union would advertise a view the portfolio endpoints cannot serve. This chart fits **honestly** rather than by coercion: a payoff curve is *derived* from the portfolio plus a proposed order, the portfolio is the priced snapshot at `as_of` (`portfolio.price(...)` is the domain's one source of price, the same call the `payoff` tool makes), and the order is not portfolio data so it arrives as declared options. The derivation is one call to the domain's own `payoff_curve`; no rule moved into the presenter. **This does not generalise**: the next projection over a genuinely non-portfolio result — a sale simulation that needs lot selection, anything spanning resources — will not fit, and closing that means parameterising `Projection`/`ProjectionSpec` over the domain result and giving `example` a per-projection sample. Flagged for ADR-K, not done here. |
| OD-2 | What is this chart's `fitness`? | TL — **0, always** | A payoff curve answers a question about an order that does not exist. No shape of held data implies one, so scoring it above zero would draw a confident chart of an order nobody asked about — the same failure 0014 OD-7 refused to commit with the wrong chart. `0` is what the Protocol already documents as "never auto-selected"; the selection rule needs no change. |
| OD-3 | How is the ticker bounded — the tool's case-insensitive `Ticker` pattern, or something narrower? | TL — **a closed `Literal` of the curated eight** | The tool validates the shape and lets `market_asset` raise `SymbolNotFoundError`, which the turn loop hands back as a recoverable tool error. A projection has no such loop: that exception is a `NotFoundError`, so an unrenderable ticker would leave as a **404** from a presenter, when the rule for a bad option value is a **422**. A `Literal` makes it a 422 from the options model, keeps the presenter free of a raising branch, and — because the generated prompt fragment renders an enum as `one of 'ADA', 'AVAX', …` — teaches the model exactly which tickers it may pick. A test pins the literal against `MARKET_REFERENCE`, so adding a ninth asset is a red test rather than a view that silently cannot draw it. |
| OD-4 | At what precision are prices printed? `price_display` quotes per value; 0014 OD-10 derives it from the grid step. | TL — **both, resolved once per payload** | Neither alone is right here. `price_display` alone quotes *per value*, so one DOGE ladder would mix `"$0.13"` (a grid price that happens to be exact in cents) with `"$0.1273"` — a price printed two ways in one payload, which is the ban OD-10 exists to enforce. The grid step alone would print DOGE's entry as `"$0.13"` when the grid is coarse, which is the `price_display` defect 0013 OD-4 fixed. So `price_places` takes the finer of the two — `price_display`'s own branch, widened by the grid's step — and every price in the payload uses that one number. A test asserts that on a coarse grid the result **is** `price_display(entry)`, so the two rules cannot drift. The caller's `precision` option governs money figures and is deliberately not applied to a unit price: a reader asked for round dollars, not for a price ladder that repeats itself. |
| OD-5 | `presentation.md` says `views/<name>.py` is the only file a chart touches; this chart is three. | TL — **three files, and the rule is the thing to revisit** | The chart is 404 lines of source. The 150-line budget is not negotiable in a feature PR, and `tests/unit/presentation/test_package_boundaries.py::test_every_view_module_registers_exactly_one_projection` asserts that **every** module under `views/` contains exactly one `= register(`, so a helper cannot live there. The two helpers therefore sit beside `views/`, named after the chart, exactly as the `payoff` tool's four modules sit together in `agent/tools/`. What this costs is nothing structural — no shared file is edited and D-15 holds — but the rule's sentence is now false for any chart whose options are a whole domain object. The honest fix is either `views/<name>/` as a package (and a boundary test that reads packages, not files) or a plainer statement that a chart owns its own modules; both are changes to a shared rule and a shared test, so they are flagged rather than taken here. |
| OD-6 | Does the projection carry 0014's `disclosure`, or is the tool's copy enough? | TL — **carry it, in the payload** | The tool's string reaches the *model*; this one reaches the *screen*, and they are not the same audience. A chart is the strongest claim in the answer — a reader who would question "this is illustrative" in a sentence accepts a plotted line — so the surface that makes the claim must carry the qualification. The wording is the projection's own and says slightly more than the tool's, naming the four things an options reading would expect and will not find: strike, expiry, implied volatility, time decay. It is **not** imported from `app.agent.tools.payoff`: the presentation layer may not import the agent layer, and `test_package_boundaries.py` enforces that. Two strings state one fact, which is a duplication worth closing — see OD-8. |
| OD-7 | A browser cannot pass an order on `GET …/views?view=payoff.curve.v1`. | TL — **accepted for now; flagged, not fixed** | `ViewQuery` declares a fixed set of query parameters (`currency`, `precision`, `locale`, `sort`, `top_n`, `include_other`, `fields`) with `extra="forbid"`, so `symbol`, `size`, `side`, `range_pct` and `steps` cannot be supplied on that path: a client gets the documented defaults and nothing else. The two callers that matter today are unaffected — the **agent** sends a render intent whose `options` is an open mapping validated against the projection's own model, and `POST /v1/view-renders` carries per-entry `options` the same way — and the Flow C chart is agent-driven. But `ViewQuery` is precisely the central, hand-maintained list D-15 forbids, and it is a shared file another ticket may be editing, so widening it is not this PR's change. Recorded here so the next person does not discover it from a 422. |
| OD-8 | The payoff bounds and the disclosure now exist twice — in `app/agent/tools/payoff_limits.py` and here. | TL — **duplicated deliberately; one home is `app.domain.payoff`** | `range_pct` 5..90, `steps` 1..25 and the wording of the disclosure are facts about what a payoff curve *is*, not about who is asking for one, and both callers already import `MIN_STEPS` and `Side` from `app.domain.payoff`. The bound table belongs next to them. It was not moved here because doing so edits the agent's four modules and their tests in a PR that adds a chart, and because a security-relevant bound table is not something to move in passing. Until then these are two copies of one rule, which is the third-occurrence trigger `api-design.md` §3 names: the next caller refactors it. |
| OD-9 | The tool's `size` is a decimal string, ≤ 8 dp; this one is an integer. | TL — **integer, because the generated prompt must be true** | ADR-E D-5 rules out a JSON float, which leaves a string or an integer, and an integer is exact for the same reason 0014 OD-3 made `range_pct` an integer percent. The deciding factor is the prompt: `prompt.option_bounds` describes a `const`, an `enum`, an integer and a boolean, and falls through to `"list of names"` for everything else — so a pattern-bounded `size` string would be published to the model as `size (list of names)`, which is a lie, in the artefact whose whole job is to stop the model inventing. Teaching it `size (integer 1..1000000000)` is true. The cost is real and named: a fractional unit size (`3.25 SOL`) is not expressible as a chart option, only as a dollar amount. Closing it properly means teaching `option_bounds` about strings, which is extending exactly the `if/elif` chain D-15 says to fix at the seam rather than extend — its own change, with its own tests. |

## 9. Rollout & observability

No flag and no migration. The projection is published by importing the `views`
package, which `bootstrap` already does; it appears in `/v1/views`, in the
OpenAPI union and in the prompt fragments with no further edit. It is never
auto-selected (OD-2), so no existing response changes shape: a caller sees it
only by asking for it by id.
