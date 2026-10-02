# 0051 — The comparison ranks what it can defend

- **Area:** backend
- **Status:** Draft
- **Ticket:** GGU-136 (and answers **GGU-134**) · **Epic:** GGU-133 · **Related:** [`backend/0017`](0017-scenario-comparison.md), [`backend/0050`](0050-the-ticket-gains-a-slider-and-one-honest-button.md), ADR-K, ADR-E
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-25

## 1. Problem

The redesign's Comparison
([Figma `16655-4253`](https://www.figma.com/design/Lj2hZqiAFTClPXqXxu9v5o/UI-Kit-A2UI?node-id=16655-4253))
is not a restyle of `scenario.comparison.v1`. It is a **different table**: four
metric rows laid out row-major, a tick on the winning cell of each, a
**Recommended** column, a *Best result* pill and a footer claiming a saving.
The card as it ships is in
[`before_scenario_comparison.png`](../frontend/assets/redesign/before_scenario_comparison.png).

Two of the four rows — `Est. tax` and `Net after tax` — existed **nowhere** in
the contract or the domain, and the third novelty contradicted the card's own
compliance text: it prints *"No method is recommended"* while the frame tags
one **Recommended**.

## 2. Scope

**In:** the declared tax rates and the two rows they produce; the row-major
`rows[]` with a winner each; `columns[].caption` / `.recommended` /
`.recommendation_label` / `.kind` / `.key` / `.proceeds`; the *Best result*
badge and the footer sentence; the **Wait for long-term** timing column; the
notes that make all of it checkable.

**Out:** the client binding (**GGU-138**); any rate that claims to be a real
taxpayer's.

## 3. API contract

No new route. `scenario.comparison.v1` gains three options and several fields.

| Option | Type | Default |
|---|---|---|
| `short_term_rate` | decimal string, `RATE_PATTERN`, ≤ `MAX_RATE` (0.60) | `"0.35"` |
| `long_term_rate` | same | `"0.15"` |
| `include_wait` | bool | `false` |

| Path | Meaning |
|---|---|
| `rows[]` | `key` · `label` · `direction_label` · `winner` — the table row-major, **no figures** |
| `columns[].key` | stable id a `winner` names |
| `columns[].kind` | `lot_method` \| `timing` |
| `columns[].caption` | *default order*, *tax-optimized*, *> 12 mo hold* |
| `columns[].proceeds` | repeated per column so the row-major table is uniform |
| `columns[].est_tax`, `.net_after_tax` | at the declared rates |
| `columns[].recommended`, `.recommendation_label` | the after-tax winner |
| `summary` | `badge` (*Best result*) + `text`, the footer sentence with its figures in it |

`columns[].short_term_lots` / `.long_term_lots` change from `int` to a decimal
string. They were fields **no client could read** — `ViewPayload` has six
readers and none takes a JSON number — which spec `0050` §7b recorded and
handed here.

### `rows[]` carries no figures, deliberately

The numbers are already in `columns[]` under the same names. A payload that
shipped each twice would be two places for one fact. The client pairs
`rows[].key` with the column field of that name, which is a literal path in a
component — what N-5 asks for.

## 4. Data model & migration

None. No table, no column, no Alembic revision. Every new value is derived
from the portfolio and the options passed in.

## 5. Security notes

No new route and no new authorisation. The change worth naming is not
technical: the card now makes a **claim about money** it did not make before.
It is constrained three ways — the rate is a declared option, it is **printed
on the card**, and the *Not advice* note stays — and `test_scenario_recommends`
asserts all three together, because any one of them alone is a tax claim with
a disclaimer somewhere else.

## 6. Acceptance criteria

1. **AC-1** — Tax is computed at rates the caller declares, on **gains only**,
   and the card prints the rates it used.
2. **AC-2** — Every marked cell is the best in its row under that row's
   direction; a tie names nobody; the recommendation **is** the
   `net_after_tax` winner and nothing else.
3. **AC-3** — *Wait for long-term* is `kind: timing`; `method`'s enum still
   means exactly one thing; the column moves the tax and leaves the result.
4. **AC-4** — Nothing is removed: `short_term_pl`, `long_term_pl` and both lot
   counts are still served (`backend/0024` §7 — read the clients first).
5. **AC-5** — Both catalog artefacts regenerated; `cd backend && make gate`
   green at 100 % branch coverage.

## 7. Test plan

| AC | Tests |
|---|---|
| AC-1 | `tests/unit/domain/test_scenario_tax.py` — each half at its own rate, a loss is not a refund, holding longer is never dearer · `tests/unit/presentation/test_scenario_rates.py` — the printed rate is the one costed with, each rate moves the figure, zero means no tax, the bound and the shape are refused |
| AC-2 | `tests/unit/presentation/test_scenario_verdict.py::test_every_marked_cell_is_the_best_one_in_its_row` (both artboards), `::test_proceeds_ties_in_every_column`, `::test_the_recommendation_is_the_after_tax_winner_and_nothing_else`, `::test_a_summary_that_names_a_winner_never_claims_a_tie` |
| AC-3 | `::test_waiting_is_a_timing_column_not_a_fourth_method`, `::test_waiting_moves_the_tax_and_leaves_the_result` |
| — | `tests/unit/presentation/test_scenario_recommends.py` — the inverted 0017 OD-4 test |

Mutation checks required: no.

**The winner is asserted as a relationship, never as a literal.** It is the one
thing here that can be individually correct and collectively wrong — every
figure right, the tick on the wrong column — so the test recomputes the best
cell of every row of every render and checks the mark against it.

**Two failures worth recording.**

- `test_changing_a_rate_changes_the_figure` first read `columns[0].est_tax` and
  failed on the short rate: on the seeded portfolio FIFO consumes a single
  **long-term** lot, so its short-term part is zero. A per-column assertion
  there was testing which lots the seed happens to hold. It reads the sum
  across columns now.
- The first render printed *"every scenario leaves the same after tax"* beside
  a column marked **Recommended**, because the summary treated *the baseline
  won* as *nobody won*. Both states now have their own sentence, and
  `::test_a_summary_that_names_a_winner_never_claims_a_tie` is the assertion
  that would have caught it.

## 8. Open decisions

| # | Question | Owner | Answer |
|---|---|---|---|
| OD-1 | **GGU-134:** does the comparison compute an estimated tax, and on whose rate? | — | **Yes, at declared rates that the card prints.** The three options were: a visible assumption, a user-supplied rate, or dropping the rows. This is the first *and* the second — the rate is a bounded, defaulted, documented option, so a caller may set it, and whoever does not gets an illustrative default **stated on the surface**. Dropping the rows was free and would have left the frame's two strongest rows unbuildable. |
| OD-2 | Is *Wait for long-term* a fourth `method`? | — | **No — `kind: timing`.** Waiting is not an ordering of lots, and a fourth enum value would make `method` mean two things. The column is the same sale past every lot's first anniversary, which **holds the price still** — an assumption strong enough to get its own note rather than be implied. |
| OD-3 | Does `Proceeds` stay in the subject strip or become a per-column row? | — | **Both.** It stays on `subject` — one sale is the card's premise — and is repeated per column so the row-major table is uniform. Its row therefore always ties, which is why the frame draws no tick on it. |
| OD-4 | What happens to the two disclosures? | — | *Before tax* becomes **Illustrative rates** and states the two figures used. *Not advice* stays and is reworded: the recommendation is **arithmetic under those rates**, not advice. A card that ranked without both would be the thing GGU-134 refused. |
| OD-5 | Does `spread` grow the footer sentence, or is it a new field? | — | **New field, `summary`.** A spread is a fact about the data and names neither end better; the footer is a claim about it. Merging them would have made one field do two jobs, which is `0050`'s `controls`-is-not-`actions` ruling applied here. |

**Spec 0017 OD-4 is superseded, not broken.** *"The card ships no `recommended`
field at all"* was right while there was no rate to rank by. The test that
enforced it has been **inverted** rather than deleted, and now asserts the
narrower thing that replaced it.

## 9. Rollout & observability

Additive except for the two lot-count fields, which change type from `int` to
a decimal string — a client could not bind them before, so nothing breaks. No
flag, no migration, no new log event.
