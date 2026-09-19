# 0011 — `get_holdings_summary`: what the portfolio holds, ranked and filtered

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-39](https://somniosoftware.atlassian.net/browse/GGU-39) · **Related:** 0003 (domain), 0005 (presentation), 0006 (agent host), 0008 (attribution tool), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

The holdings tool exists — spec 0006 shipped `get_holdings_summary` as the
reference tool that proves the registration seam. It is deliberately the
thinnest thing that could work: no filter, one fixed ordering, and totals
flattened into the top level of the payload.

GGU-39 asks for the surface the demo actually lands on. That surface is the
entry point for all three flows, and the three questions it has to answer are
not the one the reference tool answers:

- *"show me just my BTC and ETH"* — a **filter**, which the tool has no way to
  express, so the model would have to drop rows itself. A model editing a tool
  result is exactly the failure mode the numbers-from-tools invariant exists to
  prevent.
- *"what are my biggest losers?"* — an **ordering by return**, which the tool
  cannot produce. Ranked by market value, a large flat position outranks a
  small one down 40 %.
- *"how is the portfolio doing overall?"* — a **return on cost**, absolute and
  proportional, which nothing currently computes. The model would have to
  divide, and it must not.

This spec closes those three gaps and gives the payload the `totals` block the
component schema expects, without adding a single new financial concept: every
figure is still derived from the aggregate GGU-5 already stores.

## 2. Scope

**In**

- `app/domain/returns.py` — `return_on_cost`, the one ratio this tool needs,
  in the layer that owns financial meaning.
- `app/core/trend.py` — `trend_of`, the up/down/flat token a widget binds to
  choose a colour, decided from the **rounded** figure so it can never disagree
  with the string next to it. Its own module rather than a fifth function in
  `display.py`: that module turns a number into *text*, this turns one into a
  *direction*, and `display.py` was at the line budget.
- `app/agent/tools/holdings_summary.py` — the tool itself.
- `app/agent/tools/holdings_query.py` — `symbols`, `sort_by`, `top_n`: which
  positions and in which order.
- `app/agent/tools/holdings_rows.py` — the row and totals shaping.
- Tests for all of the above.

**Out**

- **`logoUrl` and `category`/asset class.** The ticket lists both in the output
  shape. Neither exists in the domain (spec 0003 `Holding` is symbol, name,
  quantity, price, market value, cost basis, unrealised P/L, weight), and a
  tool that invents a logo URL or an asset class is a tool that lies. See OD-3.
- **A new projection.** `holdings.allocation.v1` already renders allocation;
  this ticket changes no view. A holdings *table* component is Epic 2.
- The prompt fragment that teaches the model when to call this — already
  generated from the registry by GGU-14, so a changed description and a changed
  argument schema propagate with no edit here.
- `simulate_sale`, `payoff` — GGU-37/38.

## 3. API contract

No HTTP surface. The tool's contract, which is what the model sees:

| Argument | Type | Default | Notes |
|---|---|---|---|
| `sort_by` | `"weight" \| "value" \| "gainers" \| "losers"` | `"weight"` | A closed set. Ties broken by symbol, so the order is total. |
| `symbols` | list of tickers, ≤ 20 | all | Normalised through `app.domain.symbols`, so `btc` and `" BTC "` are the same ask. An unknown ticker is not an error: it simply matches nothing. |
| `top_n` | `1..20` | all | Applied **after** sorting and filtering. |

Anything else is rejected (`extra="forbid"`), which the turn loop turns into a
tool error the model can recover from rather than a failed turn.

Response:

```jsonc
{
  "asOf": "2026-09-19T00:00:00+00:00",
  "totals": {
    "count": 4,                        // the whole portfolio, not the slice
    "marketValueDisplay": "$18,060.00",
    "costBasisDisplay": "$15,400.00",
    "unrealizedPlDisplay": "+$2,660.00",
    "unrealizedPlPctDisplay": "+17.27%",
    "trend": "up"
  },
  "holdings": [
    {
      "symbol": "BTC", "name": "Bitcoin",
      "quantityDisplay": "0.6", "priceDisplay": "$30,100.00",
      "marketValueDisplay": "$18,060.00", "costBasisDisplay": "$15,400.00",
      "unrealizedPlDisplay": "+$2,660.00", "unrealizedPlPctDisplay": "+17.27%",
      "weightDisplay": "62.41%", "trend": "up"
    }
  ]
}
```

`count` and `trend` are the only non-`*Display` values, and neither is a
number a human reads: `count` is a cardinality, `trend` is a UI token. Every
figure is a string produced by `app.core.display`.

`unrealizedPlPctDisplay` is `null` when the cost basis is zero — a return on
nothing is undefined, and `"0.00%"` would assert a flat position that is in
fact infinitely profitable. See OD-2.

## 4. Data model & migration

None. The portfolio is in-memory and seeded (spec 0003).

## 5. Security notes

Read-only, no I/O, no session, no settings — a tool receives only the subject
and the portfolio provider, asserted by the package boundary tests. The subject
appears in no payload and no log line. `symbols` is bounded at 20 entries of at
most 10 characters each and matched against an enum-like pattern, so the filter
cannot be used to make the tool do work proportional to the input.

## 6. Acceptance criteria

1. **AC-1** — The tool registers itself and is callable through the registry
   with no shared file edited. *(ticket AC-1)*
2. **AC-2** — Per-holding market value equals quantity × price, weights sum to
   ≈ 100 %, and the `totals` block equals the sum over the whole portfolio —
   proven against the domain, not against parsed strings. *(ticket AC-2)*
3. **AC-3** — Every UI-facing figure is a pre-formatted string; the only
   non-string values in the payload are `count` and `trend`. *(ticket AC-3)*
4. **AC-4** — Each `sort_by` value produces the documented deterministic order,
   and `symbols` produces the documented subset. An undeclared or out-of-range
   argument is rejected. *(ticket AC-4)*
5. **AC-5** — The same arguments give byte-identical output on repeated calls.
   *(ticket AC-5)*
6. **AC-6** — `trend` never contradicts the display string beside it: a P/L
   that renders as `$0.00` is `flat`, not `up`.
7. **AC-7** — A filtered call emits **no** render intent; an unfiltered call
   emits the allocation intent. See OD-1.

## 7. Test plan

| AC | Test |
|---|---|
| AC-1 | `tests/unit/agent/test_registry.py` (discovery) + `test_holdings_summary.py::test_it_describes_itself_for_the_model_to_choose_by` |
| AC-2 | `test_the_totals_agree_with_the_domain`, `test_the_weights_of_every_position_sum_to_one` |
| AC-3 | `test_every_figure_the_model_sees_is_a_display_string` — walks rows and totals, fails on any non-`*Display` key that is not `count` or `trend` |
| AC-4 | `test_each_order_matches_what_the_domain_ranks` parametrized over all four `sort_by` values; `test_weight_and_value_are_the_same_order`; `test_gainers_and_losers_are_opposite_orders`; `test_the_symbols_filter_normalises_what_it_was_asked_for`; `test_an_unknown_symbol_matches_nothing_rather_than_failing`; `test_top_n_cuts_after_sorting_not_before`; six kinds of bad argument |
| AC-5 | `test_the_same_question_twice_gives_the_same_answer` |
| AC-6 | `tests/unit/core/test_trend.py::test_a_position_that_rounds_flat_is_not_reported_as_a_move`, which asserts `trend_of` and `signed_money_display` together so they cannot drift |
| AC-7 | `test_an_unfiltered_call_asks_for_the_allocation_chart`, `test_a_filtered_call_asks_for_no_chart` |
| OD-2 | `test_holdings_rows.py` — a hand-built zero-cost position, since the seed has no airdrop |
| — | `tests/unit/domain/test_returns.py`: gain, loss, flat and zero cost basis |

Mutation checks required: **no** — this changes no authentication, rate
limiting or error masking.

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | Should a filtered call still ask for the allocation donut? | TL — **no** | `holdings.allocation.v1` renders **the portfolio**, not the tool's rows: it is handed the `Portfolio` and slices all of it. Pairing it with a filtered answer would put a whole-portfolio chart under the sentence "here are your two positions". The tool therefore emits the render intent only for an unfiltered call; a filtered call answers in text, from the same display strings. A holdings *table* projection that renders an arbitrary subset is the real fix and belongs to Epic 2. |
| OD-2 | Return on a zero cost basis — `0.00%`, `∞`, or absent? | TL — **absent (`null`)** | `Holding.cost_basis` is `ge=0`, so a zero-cost position (an airdrop) is representable. `"0.00%"` would claim a flat position; `"∞"` is not a number anyone can bind. `null` is the only honest answer, the field is documented as nullable, and the tool description tells the model to report the absolute P/L when it is missing. |
| OD-3 | `logoUrl` and `category` from the ticket's output shape | TL — **out of scope, and the domain is where they would start** | Neither is in spec 0003's `Holding`. Adding them here means the tool inventing them, which breaks numbers-from-tools in the one direction nobody checks — non-numeric fields. Whoever needs them adds them to the domain seed first (they are curated demo data, like `name`), and the tool then copies them like every other field. Recorded so the Epic 2 component schema does not assume they exist. |
| OD-4 | `weight` and `value` sort to the same order — is one of them a bug? | TL — **neither; they are aliases by construction** | `weight` is `market_value / total_market_value` and the total is constant across a single call, so ordering by weight **is** ordering by value, always — not just for the seeded portfolio. Both names are kept because the model is picking from the user's words, and "largest allocation" and "most valuable" are the same question asked twice. A test pins the equivalence so nobody later "fixes" one of them into a different order. |
| OD-5 | `gainers`/`losers` by absolute P/L or by return? | TL — **by return** | Absolute P/L is dominated by position size, which would make `gainers` a near-duplicate of `value` and leave the "what is dragging me down" question unanswered for small positions. Ordering by return on cost is what a reader means. A position with no cost basis (OD-2) has no return and sorts last in both directions, deterministically. |
| OD-6 | Rename the tool to `get_holdings`, as the ticket calls it? | TL — **no** | The ticket predates this architecture and names the function in the deleted `backend_python/` sample. `get_holdings_summary` is the name already registered, already described in spec 0006 and already taught to the model by the generated prompt fragments. The ticket's AC-1 is about the tool being registered and callable, which holds. Renaming buys nothing and costs a contract change. |
| OD-7 | The ticket asks for an unknown `sort_by` to **fall back to the default with a logged warning**. | TL — **reject instead** | That behaviour belongs to the deleted sample, which had no argument validation. Here every knob is a declared, bounded field and ADR-K D-3 is explicit: an unknown or out-of-range option is rejected, never a best-effort guess. A silent fallback is worse for exactly the caller it was meant to help — the model asks for `losers`, mistypes it, and receives a confident answer ordered the other way with no indication anything went wrong. The rejection reaches the model as a recoverable tool error it can retry, which is strictly more information than a log line nobody reads. |

## 9. Rollout & observability

No flag and no route: the tool is reachable only through a turn. The turn loop
already logs one line per turn with the tool count and reports a raising tool
to the error reporter, so nothing new is needed here. The payload shape
changed (totals moved into their own block) but nothing consumes it yet
outside the tests and the model, which is taught the shape by the tool
description on every turn.
