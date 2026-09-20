# 0008 — `compute_attribution`: what moved the portfolio, and by how much

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-36](https://somniosoftware.atlassian.net/browse/GGU-36) · **Related:** 0003 (domain), 0005 (presentation), 0006 (agent host), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

Flow A asks *"why did my portfolio move this week, and what drove it?"*. The
agent host can run tools and the presentation layer can draw a waterfall, but
nothing answers that question: the only tool reports current holdings, which
says what the portfolio **is**, not what **changed**.

The question is also not the one the existing `attribution.waterfall.v1`
projection answers. That projection walks each holding's **unrealised profit
and loss** — a comparison against what the position *cost*. "What moved it this
week" compares against what the position was *worth seven days ago*. A holding
bought two years ago can be deeply profitable and have contributed nothing to
this week's move. Conflating the two would put a confidently wrong chart in
front of a reviewer.

## 2. Scope

**In**

- `app/domain/attribution.py` — a pure `attribute_window(portfolio, window,
  symbols)` returning per-holding start value, end value, contribution and
  share of the total move, plus the portfolio totals.
- `app/agent/tools/attribution.py` — the `compute_attribution` tool, declared
  arguments, pre-formatted output, registered from its own module.
- Tests for both, including the closure invariant.

**Out**

- **A projection for window attribution.** The existing waterfall renders P/L,
  not a window; a window variant is a new view under ADR-K and belongs with the
  catalog components (GGU-16 / Epic 2). The tool therefore emits its own
  display strings and points its render intent at the existing waterfall id;
  see OD-3.
- The prompt fragment telling the model when to call this — **GGU-14**.
- `simulate_sale`, `payoff`, `get_holdings` — **GGU-37/38/39**, Mario's.

## 3. API contract

No HTTP surface. The tool's contract, which is what the model sees:

| Argument | Type | Default | Notes |
|---|---|---|---|
| `window` | `"1d" \| "7d" \| "30d"` | `"7d"` | A closed set. The model picks; it does not invent a duration. |
| `symbols` | list of tickers, ≤ 20 | all | Totals then cover only the named holdings, so a filtered waterfall still closes against its own total. |

Anything else is rejected (`extra="forbid"`), which the turn loop turns into a
tool error the model can recover from rather than a failed turn.

Every value in the response is a pre-formatted string: `startValueDisplay`,
`endValueDisplay`, `changeDisplay`, `changePctDisplay`, and per contribution
`contributionDisplay`, `shareDisplay`, plus a `trend` of `up`/`down`.

## 4. Data model & migration

None. The portfolio and its price history are in-memory and seeded (spec 0003).

## 5. Security notes

Read-only, no I/O, no session, no settings. A tool receives only the subject
and the portfolio provider, so it cannot reach a repository even by accident —
asserted by the package boundary tests. The subject never appears in the
payload or in a log line.

## 6. Acceptance criteria

1. **AC-1** — The tool registers itself and appears in the registry with no
   shared file edited.
2. **AC-2** — Contributions sum **exactly** to the portfolio's change.
3. **AC-3** — Every figure the model receives is a display string; no bare
   number reaches it, at the top level or inside a contribution.
4. **AC-4** — The same portfolio, window and filter give byte-identical output
   on repeated calls.
5. **AC-5** — Each supported window and the `symbols` filter are honoured;
   an undeclared or out-of-range argument is rejected.
6. **AC-6** — Contributions are ordered by absolute contribution descending,
   ties broken by symbol, in the payload and not merely in the domain.

## 7. Test plan

| AC | Test |
|---|---|
| AC-1 | `tests/unit/agent/test_registry.py` (discovery) + `test_attribution.py::test_it_describes_itself_for_the_model_to_choose_by` |
| AC-2 | `test_attribution.py::test_contributions_sum_exactly_to_the_portfolio_change`, and every window in `test_every_supported_window_closes` |
| AC-3 | `test_every_figure_the_model_sees_is_a_display_string` — walks the payload and fails on any non-`*Display` key that is not a known scalar |
| AC-4 | `test_the_same_portfolio_and_window_attribute_identically` (domain) and `test_the_same_question_twice_gives_the_same_answer` (tool) |
| AC-5 | parametrized over all three windows, the filter, and four kinds of bad argument |
| AC-6 | `test_the_rows_are_ordered_biggest_mover_first`, compared against the domain result rather than by parsing formatted strings back into numbers |

Mutation checks required: **no** — this changes no authentication, rate
limiting or error masking.

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | Should the waterfall close exactly, or within an epsilon? | TL — **exactly** | Every figure is a `Decimal` derived from the same prices, and the totals are computed *from* the contributions, so closure is structural. An epsilon would hide a real defect. **The shares do not close**, and cannot: a ratio is a division, and division is inexact. The chart is drawn from the contributions; a test pins the distinction so nobody later "fixes" it by rescaling the ratios. |
| OD-2 | A share above 100 %, or a negative one — bug or fact? | TL — **fact** | When holdings move in opposite directions, one can contribute 132 % of the net move while another offsets −32 %. That is what a waterfall shows and it is arithmetically correct. Clamping it would misstate the answer. Named here because it looks wrong at a glance. |
| OD-3 | Does this ticket add a window-attribution projection? | TL — **no** | The existing `attribution.waterfall.v1` renders unrealised P/L, a different question. A window variant is a new view under ADR-K and belongs with the catalog components. The tool returns its own display strings, which is the numbers-from-tools path, and points its render intent at the existing waterfall. **Whoever builds the window projection should give it its own id** rather than changing what `v1` means. |
| OD-4 | A free-form window such as `"90d"`? | TL — **no** | The seeded history is 90 days; a free-form duration invites the model to ask for a year and receive a silently truncated answer. A closed set makes the refusal explicit. |

## 9. Rollout & observability

No flag and no route: the tool is reachable only through a turn, and the turn
is reachable only once GGU-3 lands the transport. The turn loop already logs
one line per turn with the tool count and reports a raising tool to the error
reporter, so nothing new is needed here.
