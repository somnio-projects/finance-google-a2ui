# 0017 — `scenario.comparison.v1`: the same sale, side by side

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-41](https://somniosoftware.atlassian.net/browse/GGU-41) · **Related:** 0003 (domain), 0005 (presentation layer), 0013 (`simulate_sale`), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

Flow B's first surface answers *"what would selling 0.18 BTC realise?"* — one
sale, one lot-selection method, lot by lot (spec 0013). Its second surface
answers the question the first one provokes: *"…and would a different method
be better?"*

Under FIFO the sale consumes the oldest lot; under LIFO the newest; under HIFO
the dearest. The units, the price and the proceeds are identical in all three
cases — but the **cost basis** the sale consumes differs, so the realised
profit differs, and so does the split between short- and long-term. On the
seeded BTC position the three methods disagree by $2,520.00 on the same
0.18 units, and they disagree on whether the whole result is short-term or
long-term. That is a decision a reader can only make by seeing the cases next
to each other.

Nothing renders that today. Spec 0013 deliberately shipped **no** projection
(its OD-5: "a tax-lot table projection … is explicitly out of the ticket"), so
the comparison exists only as three separate tool calls whose results the model
would have to line up itself — which means the model arranging financial
figures into a table, which is precisely what ADR-E's numbers-from-tools rule
and ADR-K D-5 forbid.

A card that puts two figures side by side is also making a **claim**: that they
are the same kind of thing, measured the same way, and therefore that the
difference between them means something. Most of this spec is about which
claims the card is allowed to make.

## 2. Scope

**In**

- `app/presentation/scenarios.py` — the DTO fragments this card is built from
  (`ScenarioSubject`, `ScenarioColumn`, `ScenarioSpread`) and its fixed notes.
- `app/presentation/scenario_options.py` — the bounded options model and the
  rules that resolve its two `null` defaults against the data.
- `app/presentation/scenario_build.py` — the pure builders that fill the
  fragments from a `SaleSimulation`, plus `signed_money` and `price_pair`.
- `app/presentation/views/scenario_comparison.py` — the projection: id, payload
  DTO, pure `render`, A2UI adapter, `fitness` and its own `register(...)` call.
- Tests for all four. Why four modules and not one: OD-8.

**Out**

- **A recommendation.** No `recommended` field, no ranking, no star, no
  ordering by outcome. See OD-4.
- **Comparing anything other than the lot-selection method.** See OD-3.
- **Tax rates, a tax bill, wash-sale rules, fees.** Same boundary spec 0013
  drew; the card reports the realised result and its term split, and says in
  its own footnote that this is what it is.
- **Committing anything.** `simulate_sale` never saves, and neither does a
  presenter.
- **A fourth lot-selection method.** `app.domain.lot_selection` owns that
  decision; this card renders whatever `LotMethod` offers.
- **Editing any shared file.** Per ADR-K D-15 the card is additive: no registry
  edit, no enum, no `if/elif`, no change to `fragments.py` (see OD-7).

## 3. API contract

No new HTTP route. The projection is served by the endpoints that serve every
portfolio projection — `GET /v1/portfolios/{portfolio_id}/views?view=…` and
`POST /v1/view-renders` — and reaches OpenAPI, `GET /v1/views` and the prompt
fragments through the registry (ADR-K D-14).

### Options

Every option is declared, bounded, defaulted, described and exemplified;
`extra="forbid"` on `ProjectionOptions` turns anything else into a **422**.

| Option | Type | Default | Notes |
|---|---|---|---|
| `symbol` | ticker, `^[A-Z]{2,10}$`, or `null` | `null` | Which position the sale is costed against. `null` resolves to the position whose **open tax lots** are worth the most at the reference price, ties broken by ascending ticker — a documented selection rule (ADR-K D-13), not a guess. |
| `quantity` | decimal > 0, ≤ `10^12`, or `null` | `null` | Units the sale disposes of. `null` resolves to the **smallest open lot** of that position. See OD-2. |
| `methods` | list of `"FIFO" \| "LIFO" \| "HIFO"` | `["FIFO","LIFO","HIFO"]` | The scenarios to compare. At least 2 (a comparison of one is not a comparison), at most `MAX_SCENARIOS`, and **distinct**. |
| `currency` · `precision` · `locale` | from `DisplayOptions` | `USD` · `2` · `en-US` | Shared mixins; the card adds no formatting vocabulary of its own. |

**The cap.** `MAX_SCENARIOS = len(LotMethod)` — three today. It is derived from
the domain enum rather than written as a literal, so a fourth method raises the
cap in the same commit that adds the method and never in a different one. It is
a real bound, not decoration: four entries are rejected on length, and
`["FIFO","FIFO"]` is rejected on distinctness, because two identical columns
claim a difference that does not exist.

### Payload

```jsonc
{
  "view": "scenario.comparison.v1",
  "title": "Same sale, different lot method",
  "subject": {
    "label": "Bitcoin", "symbol": "BTC", "quantity_display": "0.18",
    "price": {"amount": "64250.00", "display": "$64,250.00"},
    "proceeds": {"amount": "11565.000", "display": "$11,565.00"}
  },
  "columns": [
    {"method": "FIFO", "label": "FIFO — oldest lots first",
     "cost_basis": {"amount": "7740.00", "display": "$7,740.00"},
     "realized_pl": {"amount": "3825.000000", "display": "+$3,825.00"},
     "short_term_pl": {"amount": "0", "display": "$0.00"},
     "long_term_pl": {"amount": "3825.000000", "display": "+$3,825.00"},
     "short_term_lots": 0, "long_term_lots": 1, "lots": ["lot-btc-01"]},
    {"method": "LIFO", "label": "LIFO — newest lots first", "…": "+$1,305.00"},
    {"method": "HIFO", "label": "HIFO — dearest lots first", "…": "+$1,305.00"}
  ],
  "spread": {
    "amount": {"amount": "2520.00", "display": "$2,520.00"},
    "differs": true, "highest": "FIFO", "lowest": "LIFO"
  },
  "notes": [ {"label": "Before tax", "text": "…"}, {"label": "Not advice", "text": "…"} ]
}
```

**Everything the reader sees is a pre-formatted string from
`app.core.display`** (ADR-K D-5, ADR-E D-2), with the exact `Decimal` beside it
for plotting. The unit price goes through `price_display`, so a sub-cent asset
ties out against the quantity next to it (spec 0013 OD-4). The only non-string
values are `short_term_lots` / `long_term_lots` (cardinalities), `differs` (a flag)
and `method` / `highest` / `lowest` (tokens).

**What is *not* in a column is the point.** `quantity`, `price` and `proceeds`
are identical under every method by arithmetic, so they live once, in
`subject`. A column holds only what genuinely varies. A reader scanning the
columns is therefore scanning differences, not re-reading the same number three
times and wondering which one moved.

## 4. Data model & migration

None. The portfolio is in-memory and seeded (spec 0003); `simulate_sale` is
read-only and a presenter is pure.

## 5. Security notes

Pure and read-only: no I/O, no session, no repository, no settings, no clock —
asserted by `tests/unit/presentation/test_package_boundaries.py` over the whole
package. Every option is bounded by shape as well as by length, so neither a
symbol nor a quantity reaches the domain as something the domain has to reject,
and `methods` is capped so the render cost is `O(MAX_SCENARIOS × lots)`.

Errors follow RFC 9457 through the existing handler and name no figure the
caller did not already supply: an over-sell surfaces the domain's
`PositionTooSmallError` (`portfolio/position-too-small`, 422), which carries the
requested and held quantities as **attributes**, never in the message (spec
0013 §5). A `POST /v1/view-renders` entry that fails this way is turned into a
per-entry problem document and does not sink the batch (ADR-K D-18).

## 6. Acceptance criteria

1. **AC-1** — The projection registers itself from its own module and reaches
   all four consumers — OpenAPI union + example, `GET /v1/views`, the prompt
   fragments, the A2UI surface — with no shared file edited. *(ADR-K D-7, D-14,
   D-15)*
2. **AC-2** — Every column of one card is costed against the **same** symbol,
   the same units and the same price; those three are rendered once, in
   `subject`, and cannot be varied per column because the options model has no
   way to express it. *(OD-3)*
3. **AC-3** — FIFO, LIFO and HIFO each consume the lot they name and produce the
   documented cost basis, realised P/L and short/long split, over the seeded BTC
   position whose age order and price order disagree with each other.
4. **AC-4** — Per-column short-term plus long-term P/L equals that column's
   realised P/L, and cost basis plus realised P/L equals the shared proceeds —
   asserted against exact `Decimal`s, never against parsed strings.
5. **AC-5** — Every figure a reader sees is a pre-formatted `*Display` string;
   the unit price goes through `price_display`; signs are explicit on profit
   and loss and absent on a flat result.
6. **AC-6** — The card carries **no** recommendation: no `recommended` field,
   no ranking, columns in the caller's requested order and never sorted by
   outcome. `spread` reports the arithmetic difference between the extremes and
   names them without calling either one better; when nothing differs it says
   so and names neither. *(OD-4)*
7. **AC-7** — An undeclared option, an out-of-range value, fewer than two
   methods, more than `MAX_SCENARIOS`, or a repeated method is a 422 and never
   a best-effort render. *(ADR-K D-3)*
8. **AC-8** — With no options at all the card renders over the seeded portfolio,
   and that render is what OpenAPI and `GET /v1/views` publish as the example —
   rendered, never hand-written. *(spec 0005 OD-2)*
9. **AC-9** — A sale larger than the position raises `PositionTooSmallError`
   rather than rendering a card of failures, and a symbol with no open lots is
   a 422 that names the symbol and no quantity. *(OD-5)*
10. **AC-10** — `fitness` is `0`: the card is never auto-selected. *(OD-6)*

## 7. Test plan

Three files, split by responsibility to stay inside the 150-line budget:
`test_scenario_comparison.py` (what the card shows),
`test_scenario_comparison_contract.py` (how it reaches its consumers) and
`test_scenario_comparison_options.py` (what it refuses).

| AC | Test |
|---|---|
| AC-1 | `test_scenario_comparison_contract.py::test_it_is_registered_and_reaches_the_catalog_and_the_prompt`; the package-wide `test_openapi_projections.py` and `test_extensibility.py` cover the rest without being edited |
| AC-2 | `::test_every_column_is_costed_against_the_same_units_price_and_proceeds`; `test_scenario_comparison_options.py::test_a_card_cannot_be_asked_to_compare_two_symbols_or_two_sizes` |
| AC-3 | `::test_each_method_consumes_the_lot_it_names`, parametrized with `ids=` over FIFO / LIFO / HIFO on the seeded BTC position, asserting the lot id, the cost basis and the term split |
| AC-4 | `::test_each_column_adds_up` over exact `Decimal`s |
| AC-5 | `test_scenario_comparison_contract.py::test_every_figure_the_reader_sees_is_a_display_string` and `::test_the_surface_binds_the_payload_without_computing_anything`; `test_scenario_comparison.py::test_the_unit_price_is_quoted_at_price_precision` over a sub-cent asset |
| AC-6 | `::test_the_card_recommends_nothing`, `::test_columns_keep_the_requested_order_and_are_never_sorted_by_outcome`, `::test_a_sale_that_closes_the_position_reports_no_difference` |
| AC-7 | `test_scenario_comparison_options.py::test_an_undeclared_or_out_of_range_option_is_rejected`, `::test_a_repeated_method_is_rejected`, `::test_fewer_than_two_methods_is_not_a_comparison` |
| AC-8 | `::test_the_defaults_resolve_to_the_largest_position_and_its_smallest_lot`; the package-wide `test_openapi_projections.py::test_every_projection_has_an_openapi_example` validates the published example against the DTO |
| AC-9 | `test_scenario_comparison_options.py::test_selling_more_than_is_held_is_refused`, `::test_a_symbol_with_no_open_lots_is_refused`, `::test_a_portfolio_with_no_lots_at_all_is_refused` |
| AC-10 | `test_scenario_comparison_contract.py::test_the_card_is_never_auto_selected` |

## 8. Open decisions

**OD-1 — `render()` takes the `Portfolio`, and the scenario lives in the
options.** The registry's `Projection` Protocol types `render` as
`Callable[[Portfolio, Any], ProjectionDto]` and `fitness` as
`Callable[[Portfolio], int]`. This card compares *several sale simulations*,
which is neither a portfolio nor a single domain result, so there were three
honest ways out:

1. Widen the Protocol to `render(DomainResultT, options)`. It is the
   theoretically right shape and it is **forbidden here**: it edits
   `registry.py` and `spec.py`, which is exactly the shared-file edit ADR-K
   D-15 says a new chart must never require.
2. Pass the simulations in. There is no seam for it — the caller
   (`ViewService`) knows the portfolio and the options and nothing else.
3. **Chosen:** keep `render(portfolio, options)` and make the *scenario* —
   symbol, quantity, methods — part of the **declared options**, then derive
   the simulations inside `render` by calling the pure `simulate_sale` once per
   method.

(3) holds because `simulate_sale` is a pure function of the portfolio: it reads
no clock (`as_of` arrives on the portfolio), touches no repository and never
saves. Deriving N results from the portfolio inside a presenter is the same
move `attribution.waterfall.v1` makes when it calls `portfolio.holdings()` and
`total_cost_basis()`; the business rule stays in `app.domain.sales`, and the
presenter stays a pure function of *(domain data, options)*. The options model
is also exactly where ADR-K D-3 wants the knobs: bounded, defaulted, validated
identically on the client path and the agent path, and rejected rather than
guessed.

**What this does expose about ADR-K.** The Protocol conflates "the domain
result a projection renders" with "the `Portfolio`". That works here only
because this card's domain result is *derivable from a `Portfolio` by a pure
function*. A future projection over a domain result that is **not** so
derivable — anything needing a repository read, a second aggregate or a clock —
genuinely cannot be expressed by this Protocol, and would have to widen it.
That is a real limitation of ADR-K D-6/D-7 as implemented, recorded here rather
than worked around; it is not a defect of this card.

**OD-2 — The defaults are documented selection rules, not magic numbers.**
Every option must be defaulted: `ProjectionSpec.example` renders the projection
at `options()` with no arguments, and the package-wide contract test requires a
`default` in every option's JSON schema. So `symbol=null` and `quantity=null`
needed meanings.

- `symbol=null` → the position whose open lots are worth the most, ties broken
  by ticker. The largest position is the one a reader is most likely to be
  deciding about, and the rule is total, so the example is byte-stable.
- `quantity=null` → **the smallest open lot of that position**. The obvious
  alternative, "the whole position", is worse than boring: when a sale closes a
  position *every method consumes every lot*, so all three columns are
  identical by arithmetic and the default card demonstrates nothing. The
  smallest open lot is the smallest sale that is always satisfiable and that
  still forces the methods to choose differently — which is the card's entire
  subject. A fraction ("half the position") would have been a magic number; a
  lot size is a fact about the data.

The whole-position case is still reachable and still honest: ask for it and
`spread.differs` is `false` and the note says the methods coincide (AC-6).

**OD-3 — What the card refuses to compare.** Two figures side by side assert
that they are the same kind of thing. This card therefore compares **one
dimension only: the lot-selection method**, holding the symbol, the units, the
price and the `as_of` fixed. It refuses:

- **Two symbols.** "0.5 BTC realises more than 40 SOL" compares two unrelated
  decisions and reads as a recommendation to sell the bigger one.
- **Two sizes.** The larger sale realises more, always, so a size comparison is
  an arithmetic tautology wearing a tax card's clothes.
- **Two instants.** The portfolio's `as_of` is fixed at seed time (ADR-F D-6);
  a card mixing two of them would be comparing the market, not the method.

The refusal is **structural, not validated**: `symbol` and `quantity` are
scalar options and `methods` is the only list, so a card comparing two symbols
or two sizes cannot be *expressed*, let alone rejected. Making comparability
unrepresentable is stronger than checking it, and it is why this card does not
mix in `FieldSelection` either — a "comparison" whose `columns` section has
been trimmed away is not a comparison, so that knob is not offered.

**OD-4 — There is no recommended scenario, and there will not be one.**
Picking a lot-selection method for someone is tax advice, and this showcase is
not licensed to give it. It is not even a close call: whether the FIFO column
(here `+$3,825.00`, all long-term) beats the LIFO column (`+$1,305.00`, all
short-term) depends on the reader's marginal rate, their carried-forward
losses, their jurisdiction and their intentions for the rest of the year — none
of which the backend knows or should ask for. A bigger realised gain is not
even reliably the *good* outcome.

Concretely, the card:

- ships no `recommended`, `best`, `score` or `rank` field;
- keeps columns in the caller's requested order and **never sorts by outcome**,
  because sorting by outcome is a ranking with the label filed off;
- reports `spread` as the plain arithmetic difference between the extremes and
  names which method sits at each end **without calling either one better** —
  naming the ends describes data already fully shown in the columns, whereas
  "choose HIFO" would be a new claim the data does not support;
- when nothing differs, says `differs: false` and names neither end, rather
  than picking an arbitrary winner out of a tie;
- carries a fixed footnote that the figures are the realised result before any
  tax rate, fee or wash-sale rule, and a second one saying in as many words
  that no method is recommended.

The model cannot smuggle one in either: it selects a registered view and fills
declared options (ADR-K D-12), and none of them is "highlight this column".

**OD-5 — An over-sell here raises; it does not render an error card.**
Spec 0013 OD-3 made an over-sell a *structured answer* for the **tool**, and
that is right there: the model is mid-turn and must recover from it in the
same loop. A projection has a different caller and a different escape hatch.
Because every column shares one symbol and one quantity (OD-3), an over-sell
fails *all* of them identically — so there is no card to draw, only an error to
report, and a "comparison" every one of whose columns is an error is not a
comparison. `render` therefore lets `PositionTooSmallError` propagate: it is a
`ValidationFailedError`, so the existing handler renders RFC 9457 **422**
`portfolio/position-too-small`, which carries the same information in the
transport's own error vocabulary instead of inventing a second error vocabulary
inside a DTO. The batch endpoint already contains such a failure per entry
(ADR-K D-18). A symbol with no open lots is the same answer, as a plain
`ValidationFailedError` naming the symbol and no quantity.

**OD-6 — `fitness` is 0: the card is never auto-selected.** The selection rule
(ADR-K D-13) picks a projection when nobody expressed a preference. "What if I
sold?" is a question nobody has asked unless they asked it, and a backend that
volunteers a sale card over a plain portfolio read is proposing a trade. The
card is rendered only when the client names it in `?view=` or the model names
it in a render intent.

**OD-7 — Two new primitives, deliberately not added to `fragments.py` yet.**
`signed_money` (a `MoneyDisplay` built with `signed_money_display`, so a profit
reads `+$3,825.00` and a loss `-$1,305.00`) and `price_pair` (a `MoneyDisplay`
built with `price_display`) are genuinely reusable — the holdings and payoff
surfaces will both want them. ADR-K D-16 allows adding a primitive to the
shared set with its own tests; this PR keeps them in
`app/presentation/scenarios.py` instead, so that the promotion to
`displays.py`/`fragments.py` happens once, deliberately, in a PR that can
update every caller at the same time rather than in a feature PR that would
edit a shared file (D-15). Flagged for that follow-up.

**OD-8 — The card is two modules, not one.** The presentation rule asks for
`views/<name>.py` to be the only file a new chart touches. Its fragments and
builders did not fit beside its options model, DTO, render, adapter and
registration inside the 150-line budget, and the budget is a gate while "one
module" is a guideline. The split follows the seam the rest of the tree already
uses — `sale_results.py` (what a sale *is*) beside `sales.py` (what it *does*)
— so `scenarios.py` holds the shapes and `views/scenario_comparison.py` holds
the projection. It cannot live inside `views/` as a second file: that package
imports every module it contains and asserts each one registers exactly one
projection.

**OD-9 — Three test lists had to be extended, and that is the design working.**
`tests/unit/presentation/test_registry.py`, `tests/unit/api/test_views_endpoints.py`,
`tests/unit/services/test_view_service.py` and
`tests/integration/test_views_flow.py` each hold a literal list of every
shipped projection id. Adding this card extends those lists. That is **not** a
violation of ADR-K D-15, which is about `src/`: no shared *source* file was
edited. The literal lists are deliberate, for the reason
`.claude/rules/backend/testing.md` gives — a projection registered without
being listed should fail loudly rather than ship invisible to the catalog, the
prompt and the client. A test that asserted "the catalog equals the registry"
would pass for a projection nobody knew existed.

> **Amended 2026-09-21 by spec [0024](0024-contract-serves-the-designs.md)
> (GGU-104).** **OD-4 stands** — the TL ruled for it against the design's
> `recommended` / `metrics[].betterWhen`. `betterWhen` is the same ranking
> moved into the client, and a per-row `best` marker is the field OD-4 names
> first. The A2UI surface now carries each note's **label and text**; it
> flattened to `text` alone, dropping *Before tax* and *Not advice*'s
> captions, which N-9 requires verbatim.
