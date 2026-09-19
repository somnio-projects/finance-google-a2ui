# 0014 — `payoff`: what a proposed order makes or loses across a price range

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-38](https://somniosoftware.atlassian.net/browse/GGU-38) · **Related:** 0003 (domain), 0006 (agent host), 0008 (attribution tool), 0011 (holdings tool), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

Flow C ends on an order ticket: the user is about to buy or sell something and
wants to see what that order does to them if the price moves. Today nothing in
the backend can answer it. `get_holdings_summary` describes what is already
held and `compute_attribution` explains what already happened; neither says
anything about a position that does not exist yet.

The question — *"what does $500 of SOL look like if it drops 20 %?"* — is
arithmetic, and it is exactly the arithmetic the model must never do. Left to
the model it would divide a dollar amount by a price, multiply a difference by
a quantity twenty-five times, and format every result: twenty-six chances to
produce a number nobody can reproduce, under a chart that looks authoritative.

This spec adds the deterministic tool that answers it, and is careful about
what "payoff" may and may not mean here. The domain (spec 0003) is a **spot**
portfolio: holdings, tax lots and a curated daily price. It has no contracts,
no strikes, no expiries and no volatility. The honest part of the ticket — a
long or short spot position's profit and loss across a bounded price range —
ships. The options half does not, and OD-8 records what the domain would need
before it could.

## 2. Scope

**In**

- `app/domain/payoff.py` — `PayoffPoint` and `PayoffCurve`: what a payoff is.
- `app/domain/payoff_pricing.py` — `payoff_curve`, the pure curve builder, and
  `order_quantity`, the one division the ticket insists happens server-side.
  Both in the domain because "what this order makes at that price" is a
  financial statement, not a way of printing one — the same reasoning that put
  `return_on_cost` there in spec 0011. Two modules because the pair is over
  the 150-line budget, split along the seam that was already there.
- `app/agent/tools/payoff.py` — the tool, registered from its own module.
- `app/agent/tools/payoff_order.py` — the declared arguments and how an order
  size is expressed.
- `app/agent/tools/payoff_rows.py` — display shaping.
- Tests for all of the above.

**Out**

- **A payoff projection.** The registry holds two projections and neither
  renders a P/L curve, so this tool emits no render intent (OD-7).
  `payoff.curve.v1` is Epic 2's.
- **Options, Greeks, implied volatility, time decay** — OD-8.
- **Whether the order could actually be filled**: holdings sufficiency, tax
  lots, realised gains and settlement belong to `simulate_sale` (GGU-37).
  See OD-11.
- The prompt fragment that teaches the model to call this — generated from the
  registry by GGU-14, so it propagates with no edit here.

## 3. API contract

No HTTP surface. The tool's contract, which is what the model sees:

| Argument | Type | Default | Notes |
|---|---|---|---|
| `symbol` | ticker, ≤ 10 chars | — | Normalised; an unknown ticker raises `SymbolNotFoundError`, which the turn loop hands back as a recoverable tool error. |
| `size` | decimal **string**, ≤ 8 dp, positive | — | How big the order is. A string, not a number: ADR-E D-5 (OD-4). |
| `size_in` | `"units" \| "usd"` | `"units"` | What `size` counts. `usd` is divided by the entry price here, never by the model. |
| `side` | `"buy" \| "sell"` | `"buy"` | `sell` is the mirror curve of a spot position, not a short (OD-6). |
| `range_pct` | int, 5..90 | `30` | How far above and below the entry price to plot, in percent (OD-3). |
| `steps` | int, 1..25 | `12` | Price steps **per side**; the curve is `2 × steps + 1` points (OD-2). |

Anything else is rejected (`extra="forbid"`), as are a missing size and a size
of zero.

Response:

```jsonc
{
  "asOf": "2026-09-19T00:00:00+00:00",
  "disclosure": "Illustrative linear spot payoff …",
  "order": {
    "symbol": "SOL", "name": "Solana", "side": "buy",
    "quantityDisplay": "3.2808399",
    "entryPriceDisplay": "$152.40",
    "notionalDisplay": "$500.00",
    "breakEvenPriceDisplay": "$152.40"
  },
  "scenarios": {
    "low":   { "priceDisplay": "$106.68", "movePctDisplay": "-30.00%", … },
    "entry": { "priceDisplay": "$152.40", "movePctDisplay": "0.00%",
               "profitLossDisplay": "$0.00", "trend": "flat", … },
    "high":  { "priceDisplay": "$198.12", "movePctDisplay": "30.00%", … }
  },
  "points": [
    {
      "priceDisplay": "$106.68", "movePctDisplay": "-30.00%",
      "positionValueDisplay": "$350.00", "profitLossDisplay": "-$150.00",
      "returnPctDisplay": "-30.00%", "trend": "down"
    }
  ]
}
```

`trend`, `symbol`, `name`, `side` and `disclosure` are the only non-`*Display`
values, and none of them is a number. `returnPctDisplay` is `null` for an
order of zero size, which the tool rejects but the domain represents — the
same honesty rule as spec 0011 OD-2, and the reason the field is nullable.

## 4. Data model & migration

None. The tool reads the seeded in-memory portfolio and the curated market
reference (spec 0003); it writes nothing.

## 5. Security notes

Read-only, no I/O, no session, no settings. Every argument is declared and
bounded: the ticker at 10 characters, the size strings by a digits-only
pattern and a length, `steps` at 25 and `range_pct` at 90 — so the largest
answer this tool can be made to produce is 51 points, whatever the model asks
for. No free-form expression, field path or template is ever interpreted from
model input (ADR-K D-3). The subject appears in no payload and no log line.

## 6. Acceptance criteria

Each one names the ticket AC it re-baselines; §8 records every divergence.

1. **AC-1** — The tool registers itself through `app.agent.registry` and is
   discovered by `load_tools()` with no shared file edited. *(ticket AC-1,
   re-baselined by OD-1: there is no ADK `LlmAgent` here.)*
2. **AC-2** — For a fixed order the curve rises for a `buy` and falls for a
   `sell`, strictly and at every step, and the P/L at the entry price is
   **exactly** zero — not approximately, because the entry price is a grid
   point by construction (OD-2). *(ticket AC-2)*
3. **AC-3** — The break-even price equals the entry price, and each scenario's
   P/L equals `(price − entry) × quantity`, sign per side, asserted against
   hand-computed `Decimal` values. *(ticket AC-3)*
4. **AC-4** — A size in `usd` resolves to `amount / entry_price` exactly, and
   the resulting notional is that amount back; a size in `units` is priced as
   given. *(ticket AC-4)*
5. **AC-5** — Every figure in the payload is a pre-formatted string; the only
   non-string values are the nullable `returnPctDisplay` and the four
   non-numeric labels. No `Decimal` and no float reaches the model.
   *(ticket AC-5)*
6. **AC-6** — The curve size is bounded by `steps ≤ 25` (51 points), an
   out-of-range request is **rejected** rather than clamped (OD-5), and the
   same arguments give byte-identical output on repeated calls.
   *(ticket AC-6)*
7. **AC-7** — Every rejection is a rejection: an unknown ticker, a missing
   size, a zero or unparseable size, an out-of-range `range_pct` or `steps`,
   an unknown `side` and an undeclared argument each raise rather than falling
   back to a default.
8. **AC-8** — The tool emits **no** render intent, and says why in its own
   module (OD-7).

## 7. Test plan

| AC | Test |
|---|---|
| AC-1 | `tests/unit/agent/test_registry.py` (discovery) + `test_payoff_arguments.py::test_it_describes_itself_for_the_model_to_choose_by`, `::test_the_description_fits_what_the_registry_publishes` |
| AC-2 | `tests/unit/domain/test_payoff.py::test_a_long_gains_with_every_step_up`, `::test_a_sell_is_the_mirror_of_the_buy`, `::test_the_entry_price_is_a_grid_point_where_nothing_is_made_or_lost`; `test_payoff.py::test_the_scenarios_name_the_ends_of_the_plotted_range` |
| AC-3 | `::test_each_point_equals_the_hand_computed_profit`, `::test_break_even_is_the_entry_price_for_a_fee_free_order` |
| AC-4 | `::test_a_dollar_amount_buys_exactly_what_it_pays_for`, `::test_the_units_a_dollar_amount_buys_are_worth_that_amount_again`; `test_payoff.py::test_a_dollar_order_is_sized_at_the_entry_price`, `::test_a_size_in_units_is_priced_as_given` |
| AC-5 | `test_payoff.py::test_every_figure_the_model_sees_is_a_display_string` |
| AC-6 | `test_payoff.py::test_the_curve_is_bounded_by_the_step_limit`, `::test_the_same_order_twice_gives_the_same_answer` |
| AC-7 | `test_payoff_arguments.py::test_a_rejected_argument_is_never_a_default` (parametrized over eight bad calls), `::test_an_unknown_ticker_is_refused_not_guessed` |
| AC-8 | `test_payoff.py::test_it_asks_for_no_chart_because_none_of_them_is_a_payoff_curve` |
| OD-2 | `tests/unit/domain/test_payoff.py::test_the_grid_is_symmetric_around_the_entry_price`, `::test_a_curve_needs_at_least_one_step_on_each_side` |
| OD-6 | `::test_a_sell_is_the_mirror_of_the_buy`; `test_payoff.py::test_a_sell_loses_where_a_buy_gains` |
| OD-4 | `tests/unit/domain/test_payoff.py::test_an_order_of_zero_size_makes_nothing_and_returns_nothing` and `test_payoff_rows.py`, the hand-built point whose return is undefined |

Mutation checks required: **no** — this changes no authentication, rate
limiting or error masking.

## 8. Open decisions

Every row is a place where the ticket, written against the deleted
`backend_python/` sample, does not survive contact with this architecture.

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | The ticket's plan edits `backend_python/{tools,portfolio,agent,prompt_builder}.py` and registers the tool on an ADK `LlmAgent`. | TL — **re-baseline** | That sample was deleted in PR #2. The equivalent here is a pure domain module plus a tool module that ends in `register(...)`, discovered by `load_tools()` (spec 0006 AC-7). No shared file is edited — not an agent's `tools=[...]` list, not an enum, not the package `__init__`. Ticket AC-1 holds in substance: the tool is registered and callable. |
| OD-2 | `points` as a free curve resolution (default 25). | TL — **`steps` per side instead** | An even point count puts the entry price *between* two samples, so "P/L at entry ≈ 0" can only ever be approximate and the chart has no anchor. `steps` price steps on each side gives `2 × steps + 1` points with the entry exactly in the middle, so AC-2 is an equality rather than a tolerance. The default of 12 gives the ticket's 25 points. |
| OD-3 | `price_range_pct: float = 0.30`. | TL — **integer percent** | ADR-E D-5 rejects floats at the money boundary, and a float ratio cannot be repaired into an exact `Decimal` afterwards. An integer percent is exact, reads the way the user asks the question ("plus or minus 30 %"), and bounds trivially. |
| OD-4 | `quantity: float` **or** `amount_usd: float`, two optional numeric fields. | TL — **one `size` string plus a `size_in` unit** | Two changes, for two reasons. *A string*, because a JSON number from a model arrives as a float and a float can no longer be made exact (ADR-E D-5) — the same rule the seed follows, where every figure is declared as a string; the pattern bounds it to digits with at most eight decimals, so an unparseable size is rejected by the schema rather than by an exception in the middle of the curve. *One field*, because with two optionals three of the four combinations are errors, and the code that reads them then carries a branch that cannot be reached and so cannot be tested — the illegal state is removed rather than validated away. A size of zero is still rejected, and the domain still represents it (its return is `None`, spec 0011 OD-2), which is what that rejection is tested against. |
| OD-5 | Ticket AC-6: a huge `points` request is **clamped**. | TL — **reject instead** | Spec 0011 OD-7 settled this for the sibling tool and ADR-K D-3 states it: an out-of-range option is rejected, never a best-effort guess. Clamping answers a question the caller did not ask and gives no sign that it happened. The rejection reaches the model as a recoverable tool error it can retry with a legal value. |
| OD-6 | What does `side="sell"` mean on a spot book? (The ticket flags this as an open question of its own.) | TL — **the mirror curve, and say so** | Nothing in this domain can be sold short: there is no borrow, no margin and no financing rate, so a "short payoff" would be a shape with no mechanism behind it. What `sell` legitimately answers is the mirror question — what the units being sold would have made, or what the sale avoids — which is `(entry − price) × quantity`. That is the ticket's sign flip, and it is honest because the payload labels the side and the disclosure says what the curve is. |
| OD-7 | Which projection renders this? | TL — **none, deliberately** | The registry holds `attribution.waterfall.v1` and `holdings.allocation.v1`. A waterfall splits one total into contributions and a donut splits a portfolio into weights; a payoff curve is a line over a price axis and is neither. Emitting one of them would put a confident, wrong chart under a correct answer. The tool returns its points and the turn answers in text until `payoff.curve.v1` exists (Epic 2). No new projection is invented here — ADR-K D-15's seam is for the ticket that owns the component. |
| OD-8 | The ticket calls this a "risk/payoff curve" and rules out Greeks, but the phrase invites an options reading. | TL — **implement the spot part; name what is missing** | Spec 0003's domain is holdings, tax lots and a daily price. There is no instrument with a strike, an expiry or a right, no volatility input and no pricing model, so every option figure would be invented. What would have to exist first, in this order: an instrument entity in `app.domain` carrying strike/expiry/right, a volatility input on the market reference, and a pricing function next to `payoff_curve` — at which point the tool gains a `view` of a second domain function rather than growing a branch. Until then the disclosure string in every payload says what the curve is and is not. |
| OD-9 | Break-even equals the entry price for a fee-free spot order — why ship a field for it? | TL — **keep it** | The order ticket binds a break-even; if the field is absent the model supplies one, which is the failure this tool exists to prevent. It is also the field that stops being the entry price the moment a fee, a spread or a financing cost is modelled, and a consumer that reads `breakEvenPriceDisplay` keeps working that day while one that read `entryPriceDisplay` silently starts lying. |
| OD-10 | Sub-dollar tickers (DOGE at `$0.1273`, ADA at `$0.4825`) render a coarse price ladder at two decimals. | TL — **accept here, fix in the market reference** | ADR-E D-3 fixes money at two decimals and this tool will not open a second formatting rule to dodge it — that duplication has already cost this project once. The real fix is a per-asset price precision carried by the curated reference, like `name` is, and used by every surface at once; the same shape spec 0011 OD-3 gave `logoUrl`. Recorded so whoever builds `payoff.curve.v1` knows the ladder is a data gap, not a bug in the curve. |
| OD-11 | Should a `sell` payoff check that the portfolio actually holds the units? | TL — **no; that is GGU-37's question** | `payoff` answers a price-exposure question about a *proposed* order and is useful before anything is held. Sufficiency, lot selection, realised gain and holding period are `simulate_sale`'s, and duplicating half of them here would give two tools with two opinions about one sale. The payload carries no position context for the same reason. |

## 9. Rollout & observability

No flag and no route: the tool is reachable only through a turn. The turn loop
already logs one line per turn with the tool count and reports a raising tool
to the error reporter, so nothing new is needed. The model learns the tool
exists from the prompt fragments and the agent card, both generated from the
registry (GGU-14, spec 0010) — adding this tool updates both with no edit.
