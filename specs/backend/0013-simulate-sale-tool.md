# 0013 — `simulate_sale`: what a sell would realise, lot by lot

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-37](https://somniosoftware.atlassian.net/browse/GGU-37) · **Related:** 0003 (domain), 0006 (agent host), 0008 (attribution tool), 0011 (holdings tool), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

Flow B is the sell scenario: *"what if I sold 0.5 BTC?"*. The answer is a
tax-lot comparator — which lots the sale consumes, what it realises, and how
much of the gain is taxed as short-term versus long-term. Three of those four
figures are arithmetic the model must never do, and the fourth (the term) is a
date comparison it must never make either.

Nothing in the backend answers it today. `get_holdings_summary` (spec 0011)
reports what a position is worth against what it cost; that is a statement
about the **whole** position at the **current** price. A sale is a different
question:

- it consumes **specific lots**, in an order the caller chooses (FIFO, LIFO,
  HIFO), and a different order gives a different tax bill on the same units;
- it splits the realised result by **holding period**, which turns on the
  1-year boundary `app.domain.terms` already owns;
- it leaves a **remaining position**, which is what makes the comparator
  readable: the user is deciding, not reminiscing.

The tax-lot data has been waiting for this since spec 0003: the seed positions
BTC deliberately with two lots at 367 and 363 days, one either side of the
boundary, and SOL with 60 bought / 20 sold / 40 open "so a simulated sale has
a real history behind it".

## 2. Scope

**In**

- `app/domain/lot_selection.py` — `LotMethod` and the three consumption
  orders. Which lot goes first is a *policy*, separable from what selling it
  does, and it is the only part of this feature a fourth method would touch.
- `app/domain/sale_results.py` — `LotConsumption` and `SaleSimulation`: what a
  simulated sale **is**.
- `app/domain/sales.py` — `simulate_sale(...)`: what it **does**. Pure, no
  clock, no I/O; `as_of` arrives on the portfolio.
- `app/domain/errors.py` — `SaleQuantityError`, `PositionTooSmallError`.
- `app/agent/tools/simulate_sale.py` — the tool: declared arguments, the
  run method, its own `register(...)`.
- `app/agent/tools/sale_rows.py` — the display shaping.
- `app/agent/tools/ratios.py` — `return_display`, the return-on-cost string
  this tool and the holdings tool both need, in one place (OD-6).
- `app/core/display.py` — `price_display`, so a unit price ties out against
  the quantity beside it for a sub-cent asset (OD-4).
- Tests for all of the above.

**Out**

- **A tax-lot table projection.** No registered projection renders this
  answer, and inventing one here is explicitly out of the ticket. See OD-5.
  *(Spec 0015 registered `taxlots.table.v1` and wired this tool to it; the
  projection itself is still that spec's, not this one's.)*
- **Committing the sale.** The simulation is read-only: it never calls
  `PortfolioProvider.save`. The ticket agrees ("Out of scope").
- **Wash-sale rules, fees, tax rates, a tax *bill*.** The tool reports the
  short/long split of the realised result. It does not apply a rate to it, and
  the description does not let the model imply that it did.
- The prompt fragment that teaches the model when to call this — generated
  from the registry by GGU-14, so a registered tool propagates with no edit.

## 3. API contract

No HTTP surface. The tool's contract, which is what the model sees:

| Argument | Type | Default | Notes |
|---|---|---|---|
| `symbol` | ticker, 2–10 letters | — | Required. Bounded by a pattern, not only by length, so `"b$"` is rejected as an argument instead of reaching the market reference and returning as an opaque `tool-failed`. Case and surrounding whitespace are normalised through `app.domain.symbols`, so `btc` and `" BTC "` are the same ask. |
| `quantity` | decimal **string**, `^\d{1,12}(\.\d{1,8})?$` | — | Units to sell. A string, not a JSON number — see OD-2. |
| `amount_usd` | decimal **string**, same pattern | — | Dollars to raise, resolved to units at the current price. |
| `lot_method` | `"FIFO" \| "LIFO" \| "HIFO"` | `"FIFO"` | Which lots the sale consumes first. |

Exactly one of `quantity` / `amount_usd` is given; neither or both is a
rejection. Anything else is rejected too (`extra="forbid"`), which the turn
loop turns into a tool error the model can recover from.

Response:

```jsonc
{
  "asOf": "2026-09-18T12:00:00+00:00",
  "summary": {
    "symbol": "BTC", "lotMethod": "FIFO",
    "priceDisplay": "$64,250.00", "quantityDisplay": "0.5",
    "proceedsDisplay": "$32,125.00", "costBasisDisplay": "$22,620.00",
    "realizedPlDisplay": "+$9,505.00", "realizedPlPctDisplay": "42.02%",
    "shortTermPlDisplay": "+$580.00", "longTermPlDisplay": "+$8,925.00",
    "shortTermLots": 1, "longTermLots": 1, "trend": "up"
  },
  "remaining": {
    "count": 1, "quantityDisplay": "0.1",
    "costBasisDisplay": "$5,700.00", "marketValueDisplay": "$6,425.00"
  },
  "lots": [
    {
      "lotId": "lot-btc-01", "acquiredOnDisplay": "2025-09-16", "term": "long",
      "quantityDisplay": "0.42", "costBasisDisplay": "$18,060.00",
      "proceedsDisplay": "$26,985.00", "gainLossDisplay": "+$8,925.00",
      "trend": "up", "fullySold": true
    },
    {
      "lotId": "lot-btc-02", "acquiredOnDisplay": "2025-09-20", "term": "short",
      "quantityDisplay": "0.08", "costBasisDisplay": "$4,560.00",
      "proceedsDisplay": "$5,140.00", "gainLossDisplay": "+$580.00",
      "trend": "up", "fullySold": false
    }
  ]
}
```

This is the **whole** answer to `{"symbol": "BTC", "quantity": "0.5"}`, not an
abbreviation of it, and
`tests/unit/agent/tools/sale_payload.py::FIFO_HALF_BITCOIN` holds the same
strings as a literal oracle. OD-9 tells Epic 2 to write the component schema
from this section, so the two are kept identical on purpose: if they drift,
one of them is wrong.

Every figure is a string from `app.core.display`. The non-string values are
`shortTermLots`, `longTermLots` and `count` (cardinalities), `fullySold` (a
flag) and `term`, `lotMethod`, `trend` (UI tokens) — none of them a number a
human reads. `realizedPlPctDisplay` is `null` when the consumed cost basis is
zero, exactly as in spec 0011 (OD-6).

**Over-sell** is not an exception the model never sees; it is an answer:

```jsonc
{
  "asOf": "…", "error": "position-too-small", "symbol": "BTC",
  "requestedDisplay": "1.5", "heldDisplay": "0.6"
}
```

See OD-3 and OD-4.

## 4. Data model & migration

None. The portfolio is in-memory and seeded (spec 0003), and the simulation
mutates nothing.

## 5. Security notes

Read-only, no I/O, no session, no settings — a tool receives only the subject
and the portfolio provider, asserted by the package boundary tests. The subject
appears in no payload and no log line. Every argument is bounded, by shape as well as by
length: `symbol` to 2–10 letters, the two sizes to at most 12 integer and 8
fractional digits, so neither can make the walk do work proportional to the
input and neither reaches the domain as something the domain has to reject. `PositionTooSmallError` carries the requested and held quantities as
**attributes**, not in its message: the message is what an RFC 9457 body would
render if this error ever reached HTTP, and a portfolio's holdings do not
belong in one.

## 6. Acceptance criteria

1. **AC-1** — The tool registers itself and is callable through the registry
   with no shared file edited. *(ticket AC-1, re-baselined — OD-1)*
2. **AC-2** — Per-lot proceeds, cost basis and gain/loss sum exactly to the
   summary totals, and the short-term plus long-term split equals the total
   realised P/L — asserted against the domain, never against parsed strings.
   *(ticket AC-2)*
3. **AC-3** — FIFO, LIFO and HIFO each consume the lot they name and yield
   the documented realised P/L, proven over a position whose age order and
   price order disagree — the seed's BTC lots cannot tell LIFO from HIFO,
   because there the newest lot is also the dearest. *(ticket AC-3)*
4. **AC-4** — A lot two days inside the 1-year boundary is short-term and one
   two days past it is long-term, at a fixed `as_of`. *(ticket AC-4)*
5. **AC-5** — Every UI-facing figure is a pre-formatted string; the only
   non-string values are the cardinalities, the flag and the tokens listed in
   §3. *(ticket AC-5)*
6. **AC-6** — Selling more than the position holds returns the structured
   `position-too-small` payload with both quantities pre-formatted, consumes
   no lot and leaves no negative quantity anywhere; `quantity` and
   `amount_usd` both resolve to the same sale when they describe the same
   sale. *(ticket AC-6)*
7. **AC-7** — The same arguments give an identical payload on repeated calls,
   and every consumption order is total: no two runs differ on a tie.
   *(ticket scope item 4)*
8. **AC-8** — ~~The tool emits **no** render intent~~ — **superseded by AC-9
   when spec 0015 registered the projection.** The payload still names no
   view: a view is a render intent, never a field the model reads. *(OD-5)*
9. **AC-9** — The tool emits a **`taxlots.table.v1`** render intent on a
   **successful** simulation, naming the scenario that was actually costed
   (`symbol`, `quantity` in units, `lot_method`) — and **none** on the
   `position-too-small` refusal, where there are no lots to draw. The
   intent's options validate against the projection's own options model and
   render a table that names the same lots and the same realised result as
   the payload beside it. *(spec 0015, OD-5)*

## 7. Test plan

Six test files, split by responsibility to stay inside the 150-line budget:
`test_sales` (what a sale realises) / `test_sales_limits` (where it stops and
what it refuses); `test_simulate_sale` (the payload) /
`test_simulate_sale_sizes` (how a size is named) /
`test_simulate_sale_refusals` (what the tool turns down), with the published
example held as a literal oracle in `sale_payload.py`.

| AC | Test |
|---|---|
| AC-1 | `tests/unit/agent/test_registry.py::test_load_tools_discovers_every_tool_without_a_shared_list`, parametrized over **every** tool name this backend ships, plus `::test_every_module_that_registers_a_tool_is_named_in_the_expected_list` so a tool added without being listed fails rather than shipping invisible to the model; `test_simulate_sale.py::test_it_describes_itself_for_the_model_to_choose_by` and `::test_its_description_fits_what_the_model_is_told` (the 512-character `ToolSpec` bound) |
| AC-2 | `test_sales.py::test_the_consumed_lots_sum_to_the_totals` and `::test_the_term_split_sums_to_the_realised_result`; `test_sales_limits.py::test_a_simulation_whose_rows_do_not_reach_its_totals_does_not_close`, so `closes()` is known to be able to fail |
| AC-3 | `test_sales.py::test_each_method_consumes_the_lot_it_names`, parametrized with `ids=` over a hand-built position whose age order and price order disagree, asserting the lot id **and** the realised P/L; `test_lot_selection.py` for the orders themselves, including the tie-break; `test_simulate_sale.py::test_the_lot_method_changes_which_lots_the_answer_names` at the tool's boundary |
| AC-4 | `test_sales.py::test_a_sale_spanning_the_boundary_splits_short_from_long` at the frozen `as_of`, over the 367/363-day seeded BTC lots |
| AC-5 | `test_simulate_sale.py::test_the_published_example_is_the_answer_it_publishes` pins **every string** of §3 against the literal oracle — the only test that notices a summary whose short-term and long-term figures are swapped, since every invariant is symmetric under that swap; `::test_every_figure_the_model_sees_is_a_display_string` walks the keys; `test_sale_rows.py` for the nullable percentage and the leftover block |
| AC-6 | `test_simulate_sale_refusals.py::test_selling_more_than_is_held_answers_instead_of_failing`, `::test_a_sale_takes_exactly_one_size`, `::test_an_undeclared_or_out_of_range_argument_is_rejected`; `test_simulate_sale_sizes.py::test_dollars_and_units_describe_the_same_sale`; `test_sales_limits.py::test_a_sale_larger_than_the_position_is_rejected`, `::test_the_rejection_carries_both_quantities_but_says_neither`, `::test_a_symbol_in_the_market_but_not_held_reports_holding_none`, `::test_a_non_positive_sale_is_rejected` |
| AC-7 | `test_simulate_sale.py::test_the_same_question_twice_gives_the_same_answer`; `test_lot_selection.py::test_lots_that_tie_are_ordered_by_id`, parametrized over all three methods |
| AC-8 | `test_simulate_sale.py::test_the_payload_names_no_view_of_its_own` |
| AC-9 | `test_simulate_sale_render.py::test_a_successful_simulation_asks_for_the_tax_lot_table`, `::test_the_intent_names_a_projection_the_registry_really_holds`, `::test_the_intents_options_validate_against_the_projections_own_model`, `::test_the_rendered_table_names_what_the_answer_names`, `::test_a_dollar_sized_ask_travels_as_the_units_it_resolved_to`; `test_simulate_sale_refusals.py::test_selling_more_than_is_held_answers_instead_of_failing` for the refusal's absent intent |
| OD-2 | `test_simulate_sale_refusals.py::test_an_undeclared_or_out_of_range_argument_is_rejected` — eight bad arguments, each with its own `id`, including the hostile ticker the length bound alone let through |
| OD-4 | `test_simulate_sale_sizes.py::test_dollars_resolve_to_a_quantity_the_reader_can_multiply_back` and `::test_dollars_and_units_describe_the_same_sale`, both against **literal** oracles (`"0.15564202"`, `"$10,000.00"`) rather than the resolver under test; `::test_a_sub_dollar_price_is_shown_at_the_precision_it_is_quoted_to` for DOGE; `::test_a_dollar_amount_at_the_edge_of_the_position_does_not_guess` for the cent either side of the whole position; `::test_a_dollar_amount_too_small_to_buy_a_unit_is_rejected`; `tests/unit/core/test_display.py::test_price_display_carries_the_precision_the_price_is_quoted_to` and `::test_a_sub_cent_price_would_not_tie_out_if_it_were_flattened`; `tests/unit/domain/test_market.py::test_every_reference_price_fits_the_display_precision` |
| OD-6 | `tests/unit/agent/tools/test_ratios.py` — gain, loss, flat and a zero cost basis; `test_sale_rows.py::test_a_sale_of_something_that_cost_nothing_has_no_percentage` |

**Mutation evidence** (run before the PR, tree restored after each): commenting
out `register(SimulateSaleTool())` → 2 failures; swapping
`shortTermPlDisplay` with `longTermPlDisplay` → 1 failure; rendering
`priceDisplay` from the proceeds → 3 failures; rendering the leftover cost
basis from the consumed one → 1 failure. Each of those was green before the
review.

Mutation checks required: **no** — this changes no authentication, rate
limiting or error masking.

## 8. Open decisions

The ticket was written against the deleted `backend_python/` sample, whose
implementation plan names `portfolio.py`, `tools.py`, `agent.py`,
`prompt_builder.py` and an ADK `LlmAgent`. None of those exist. Every
divergence from it is recorded here.

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | The ticket's file plan (`backend_python/{portfolio,tools,agent}.py`, `tools=[...]` on an ADK `LlmAgent`, a `py.typed` marker, a `pyproject.toml` that needs pydantic and a test runner added). | TL — **re-baseline onto spec 0006** | The sample is gone. The domain walk lives in `app/domain/{lot_selection,sale_results,sales}.py`, the tool in `app/agent/tools/{simulate_sale,sale_rows}.py`, and registration is the discovery seam (ADR-K D-7): the module ends in `register(SimulateSaleTool())` and **no shared file is edited** — there is no `tools=[...]` list to append to, which is the point. `py.typed`, pydantic and the test runner have shipped since spec 0001. The ticket's AC-1 ("registered and callable, proven by the registration test") survives the re-baseline verbatim; only the mechanism changed. |
| OD-2 | The sale size is a number. How does it cross the model boundary? | TL — **as a decimal string** | ADR-E D-1 forbids `float` in the portfolio domain, and `app.domain.money.reject_float` enforces it at the model boundary. A JSON number parses to `float`: `0.1` becomes `0.1000000000000000055…` before this code sees it, and no later conversion repairs it. So `quantity` and `amount_usd` are pattern-bounded **strings** parsed with `Decimal(...)`, and the tool description tells the model to write the number as a string. The alternative — accepting a float and laundering it through `Decimal(str(x))` — would work today and would be the exact habit ADR-E exists to break. |
| OD-3 | Over-sell: "partial fill / error", says the ticket. Which? | TL — **neither; a structured answer** | A partial fill answers a question nobody asked: the user asked what selling 1.5 BTC does, and quietly costing out 0.6 hands the model figures it will present as the answer. That is spec 0011 OD-7's silent-fallback failure with a bigger blast radius. Raising is not right either: the turn loop masks a raising tool as `{"error": "tool-failed"}` (deliberately — a message can quote a holding), so the model would lose the one fact that makes the answer useful. The tool therefore **catches** `PositionTooSmallError` at its boundary and returns `{"error": "position-too-small", "requestedDisplay", "heldDisplay"}`, both pre-formatted. The model copies "you hold 0.6" instead of inventing it. Invalid *arguments* still reject, unchanged. |
| OD-4 | `amount_usd` divided by a price rarely lands on a round number of units, and a price rarely lands on a round number of cents. What does the payload show? | TL — **quantize the size to 8 dp before the walk; show the price at the precision it is quoted to** | `$1,000 / $3,180.50` is 0.31441…, 28 digits of it. ADR-E D-3 bans rounding in intermediate arithmetic, but a trade size is not an intermediate figure — it is an **input**, the same one an exchange would round to a lot size. Quantizing it to `QUANTITY_PRECISION` (8 dp, half-even) before anything is computed is what makes the ticket's own hand-check hold: *proceeds = the displayed quantity × the displayed price*, exactly. Because a reader does that multiplication, the **price** has to be exact too, and two decimal places is not: DOGE is quoted at $0.1273, and `$0.13 × 12,000` reads $1,560.00 against proceeds of $1,527.60 printed in the same block. `app.core.display.price_display` therefore carries `PRICE_PRECISION` (4 dp) when cents are not enough, and a test over the curated reference fails if an asset is ever quoted finer than that. Quantizing a dollar size can only round **down** into the position, never up into an over-sell — pinned for the cent either side of the whole position. A dollar amount too small to buy 1e-8 units resolves to zero and is rejected as a non-positive sale. |
| OD-5 | Which projection should the tool ask for? | TL — **none, and do not invent one** | Two projections are registered: `attribution.waterfall.v1` and `holdings.allocation.v1`. The waterfall answers what moved the portfolio; the donut renders the **whole** portfolio's allocation and would sit under a sentence about one symbol — spec 0011 OD-1 already rejected that pairing for a *filtered holdings* answer, and a single-symbol sale is a narrower answer still. ADR-K D-11/D-12: the model picks from the registry and never invents a shape, and a tool pointing at a view that does not exist is the same lie one step earlier. The tool emits no render intent; the answer is text built from the display strings. `taxlots.table.v1` is Epic 2's, and it arrives with the component, not ahead of it. **Superseded 2026-09-19 by [spec 0015](0015-tax-lot-table-projection.md):** the component landed, so the reason to point at nothing is gone. The tool now emits `RenderIntent(view="taxlots.table.v1", options={symbol, quantity, lot_method})` on a **successful** simulation only — the `position-too-small` refusal still emits none, because a tax-lot table under "you hold fewer units than that" is the same contradiction spec 0011 OD-1 rejected. The ordering this decision asked for held: the surface arrived first, then the tool pointed at it. Note the id lost its underscore on the way (spec 0015 OD-2). See AC-9. |
| OD-6 | Realised P/L as a percentage — of what, and what when there is nothing to divide by? | TL — **of the consumed cost basis, `null` when it is zero** | Same ratio and same answer as spec 0011 OD-2, through the same `app.domain.returns.return_on_cost`; no second return function is written. The small helper that turns it into a string (or `None`) was private to `holdings_rows`; it moves to `app/agent/tools/ratios.py` and both tools import it, rather than existing twice with one copy free to drift. |
| OD-7 | Term classification — derive it here, as the ticket's design implies? | TL — **no, reuse `app.domain.terms`** | `TaxLot.term(as_of)` already answers it, the 365-day boundary rule is documented there, and `tests/unit/domain/test_terms.py` already pins the off-by-one. This feature re-derives nothing; its boundary test asserts that a *sale* classifies its lots with the same rule, over the seeded 367/363-day BTC lots. The ticket's AC-4 is proven at the sale level, where it was asked. |
| OD-8 | The ticket names three lot methods and says nothing about ties. | TL — **every order is total, tie-broken on `lot_id`** | Two lots acquired the same day (FIFO/LIFO) or carrying the same unit cost (HIFO) must not consume in whatever order the seed happened to list them: determinism (ticket scope item 4) has to be structural, not incidental. Each ordering therefore ends in `lot_id` ascending, and a test builds a deliberate tie rather than trusting the seed not to have one. |
| OD-9 | The ticket's field names (`acquireDateDisplay`, a flat `summary`). | TL — **keep the shape, align two names with the domain** | `acquireDateDisplay` becomes `acquiredOnDisplay`, matching `TaxLot.acquired_on`, and `lot_method` is echoed as `lotMethod`. The payload gains a `remaining` block, which the ticket's scope asks for ("the remaining position") but its output shape omits. Nothing consumes the payload yet outside the tests and the model, and the Epic 2 component schema should be written from §3 of this spec rather than from the ticket. |

## 9. Rollout & observability

No flag and no route: the tool is reachable only through a turn. The turn loop
already logs one line per turn with the tool count and reports a raising tool
to the error reporter, so nothing new is needed here.

No diagram changes. `03-backend-layers.md` draws `domain/*` and `agent/*` as
layers, not as module lists, and this feature adds no layer, no dependency
direction and no new import edge — `agent` still reaches only `core` and
`domain`. `05-agent-turn.md` draws the turn mechanics, and this tool uses them
unchanged: one more registered tool and no new step. It asked for no render
intent until spec 0015 gave it one to ask for; the arrow is now the same as its
siblings' (AC-9).
