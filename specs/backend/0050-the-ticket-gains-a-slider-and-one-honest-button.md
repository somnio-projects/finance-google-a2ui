# 0050 — The ticket gains a slider, and one honest button

- **Area:** backend
- **Status:** Draft
- **Ticket:** GGU-137 · **Epic:** GGU-133 · **Related:** [`backend/0031`](0031-order-ticket-v2.md), [`backend/0018`](0018-order-ticket-projection.md), [`backend/0046`](0046-no-equity-vocabulary-in-a-crypto-payload.md), [`frontend/0013`](../frontend/0013-order-ticket-v2.md), ADR-K
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-25

## 1. Problem

The redesign's Order Ticket frame
([Figma `16659-7833`](https://www.figma.com/design/Lj2hZqiAFTClPXqXxu9v5o/UI-Kit-A2UI?node-id=16659-7833))
draws two things `order.ticket.v2` cannot serve: a **draggable track** beside
every stepper, and a **live primary button**. The card as it ships today is in
[`before_order_ticket_v2.png`](../frontend/assets/redesign/before_order_ticket_v2.png).

Neither is a widget choice.

- A slider is continuous and this contract is not. The money total, the
  weight, the cash remaining and every weight shift move with the value, and a
  client may compute none of them (N-2). The stepper works only because each
  of its two neighbours is a **pre-computed basket**, written server-side.
- The button is already on the card, drawn deliberately **disabled**, because
  the contract declares no action for it. But its label — `Review order`, and
  `Save as draft` beside it — is a **Dart constant** in
  `order_ticket_v2_buttons.dart`. That is design's copy compiled into the
  bundle, unable to follow the `locale` option: N-9 with the sentence pointing
  the wrong way.

## 2. Scope

**In:** the slider's stops as declared fields; the ladder that writes them; the
button's label, kind, enabled state and reason as a declared field; retiring
`Save as draft`; both catalog artefacts.

**Out:** the impact strip's fourth cell (**GGU-135** — design owes the
answer); making any control live (see OD-2); the client binding (**GGU-139**).

## 3. API contract

No new route. `order.ticket.v2`'s payload gains three fields.

| Path | Type | Meaning |
|---|---|---|
| `lines[].stops` | `tuple[str, …]`, ≤ `MAX_LADDER` (23) | Every `legs` option value this leg's track can land on, ascending by this leg's units. Each matches `LEGS_PATTERN` and is accepted by `OrderTicketV2Options`. |
| `lines[].position` | `int`, `0 ≤ n < MAX_LADDER` | Index into `stops` of the value this line is rendered at. |
| `controls[]` | `tuple[TicketControl, …]`, ≤ 4 | `key` · `label` · `kind` · `enabled` · `reason`. |

Nothing is removed. `increment` / `decrement` stay: they are the fine,
keyboard-reachable control, and the slider is the coarse one.

### The ladder rule

`app/domain/draft_ladder.py`, pure, no I/O:

1. **Ceiling.** A **buy** is bounded by cash — what the available cash affords
   for this leg once the *other* legs are paid for, floored to the asset's own
   `step`. A **sell** raises cash and is never blocked (`draft_impact`), so it
   is bounded by what the portfolio **holds**. Either way it is never below the
   quantity on screen, so a draft already past its cash still sits on its own
   track.
2. **Stride.** The asset's `step`, coarsened by `ceil((span + 1) / MAX_STOPS)`
   so the ladder fits its bound. A payload is not a place for an unbounded list.
3. **Alignment.** The ladder is built around the **current** value, not around
   zero, so the number on screen is always a stop. Zero and the ceiling are
   added, so both ends are always reachable.

### `controls` is not `actions`, and the name is load-bearing

`contract.py` and `catalog_json.py` read a payload field named `actions` as the
`SurfaceActionRef` list — *what this surface may send back* — and render it
into the catalog's actions table. This ticket sends nothing back: one `effect`,
`recalculate`, no endpoint, no callback, no submit (0018 OD-2). A button that
is **drawn and does not fire** is a different claim and gets a different word.

## 4. Data model & migration

None. No table, no column, no Alembic revision. The projection is pure and
every new value is derived from the market reference and the portfolio passed in.

## 5. Security notes

No change to the threat model. No new route, no new option, no new input: the
stops are *output*, written by the backend from the same bound
`OrderTicketV2Options` enforces, so a caller sending one back is validated
exactly as a stepper value is. `controls[].enabled` is `false` on every entry
served, which is the point: nothing on this surface can place, send or settle,
and the disclosure continues to say so.

## 6. Acceptance criteria

1. **AC-1** — Every line carries a bounded ladder of legal `legs` values, with
   `position` indexing the value on screen. Whatever either control sends, the
   render it produces puts the thumb on the number it sent.
2. **AC-2** — The button's label, kind, enabled state and reason are served.
   Every control is `enabled: false` with a reason while `effect` is the whole
   contract.
3. **AC-3** — `Save as draft` is no longer served.
4. **AC-4** — Both catalog artefacts regenerated and committed.
5. **AC-5** — `cd backend && make gate` green, 100 % branch coverage.

## 7. Test plan

| AC | Unit tests |
|---|---|
| AC-1 | `tests/unit/domain/test_draft_ladder.py` — alignment, both ends, ascent, one leg moved, the bound, the buy ceiling as a relationship, the sell ceiling, an unheld asset |
| AC-1 | `tests/unit/presentation/test_order_ticket_v2_controls.py::test_a_stepper_move_lands_on_a_ladder_that_holds_it`, `::test_a_slider_move_round_trips_the_same_way`, `::test_every_stop_is_a_legs_value_the_options_model_takes_back` |
| AC-2, AC-3 | `::test_the_one_control_is_drawn_inert_and_says_why`, `::test_no_control_is_ever_live_while_the_ticket_places_nothing`, `::test_save_as_draft_is_not_served` |

Mutation checks required: no. Nothing here touches auth, rate limiting or
error masking.

**One test failure is worth recording, because it corrected the spec rather
than the code.** The first draft asserted `increment in line.stops` — "one
ladder, two affordances, they cannot disagree" — and it failed: the stepper
moves one asset step (`0.06 → 0.07`) while the ladder's stride is four
(`0.02, 0.06, 0.10`). The claim was wrong. They are **two granularities of one
quantity**, and the invariant that actually holds is the round trip: the ladder
is aligned to the current value, so whichever control moved it, the next
render's thumb sits on the new number. The assertion was rewritten to that, and
three docstrings that had repeated the false claim were corrected with it.

## 7b. A field the client cannot read is not a field

Both new fields were first written the obvious way — `position: int`,
`enabled: bool` — and **one of them was unreadable**. `ViewPayload` has exactly
six readers and no more:

| Reader | Accepts |
|---|---|
| `text` / `optionalText` | a JSON **string** |
| `geometry` | a **decimal string**, for a canvas coordinate |
| `strings` | an array of strings |
| `rows` | an array of objects |
| `flag` | a JSON **bool** |

There is **no reader for a JSON number.** `text` throws on one, and `geometry`
throws too — it requires a decimal *string* (ADR-E D-5: a decimal that has been
through a JSON float can no longer be made exact). So `position: int` would
have shipped a field that raises `PayloadContractException` on the first bind.
It travels as a decimal string and is read through `geometry`, which is exactly
what that seam is for: a thumb's index is a position on a track and never
reaches a `Text`.

`enabled: bool` needed no change, and the first draft of this spec changed it
anyway — to a `"live" | "inert"` string, on the reasoning that this contract
uses strings for `badge` and `breach` because the client cannot read a bool.
That reasoning was **wrong**: `flag` exists, in `view_payload_flag.dart`, a
`part` file a grep of `view_payload.dart` does not show. The change was
reverted.

**The latent defect this turned up is not ours to fix here.** Walking every
example in the catalog for scalars the client has no reader for finds three
live ones, in two other views:

```
scenario.comparison.v1   columns[].short_term_lots   int
scenario.comparison.v1   columns[].long_term_lots    int
taxlots.table.v1         by_term[].lots              int
```

None is bound today, so nothing is broken — but each is a field that *cannot*
be bound, published as though it could. They are counts, so a `count` reader or
a decimal string would both serve. Recorded here rather than fixed, because
`scenario.comparison.v1` is **GGU-136**'s subject and changing it under this
ticket would put two contracts in one PR.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Does the slider set **units** or the leg's **weight in the order**? | design | **Units**, decided here. The frame's thumb sits at the weight (40/35/25, summing to 100), which reads as though the slider set the share. It does not: a weight control needs a second option, its edits are **non-local** — moving one leg redistributes the others — and the row would carry two controls governing two different quantities. Weight stays an output. |
| OD-2 | Does `Review order` ever become live? | design/product | **No.** There is no broker, and the disclosure says nothing is ever sent, placed or settled. It is served drawn, `enabled: false`, with the reason. **The frame needs a disabled state it does not yet have** — an enabled-looking dead button is what `frontend/0013` OD-3 refused. |
| OD-3 | What happens to `Save as draft`? | design | **Dropped.** It was the second placeholder, the frame draws no second action, and a control with no contract behind it and no design asking for it is one nobody decided about. |
| OD-4 | The thumb sits **low** on the track, and design should see it before the client is built. | design | Kept. The ceiling is affordability, so BTC's track runs `0 … 0.71` with the draft at `0.06` — the thumb at ~10 %, not the frame's 40 %. That is the honest meaning of "how much of this can I buy"; if design wants the thumb nearer the middle, the ceiling needs a different rule and that is a design decision, not an arithmetic one. |
| OD-6 | Should the three unreadable `int` fields in §7b become readable, or be removed? | GGU-136 / a tax-lot ticket | Left as they are here. A count nobody binds is a candidate for removal (`backend/0024` §7: *read the clients first*), and both views have an owner. |
| OD-5 | Is the tinted/selected leg payload state or client focus? | — | **Client focus.** It carries no meaning the backend knows: no action selects a leg, no figure depends on which is highlighted, and no option names one. It is widget state, like a text field having focus — the opposite answer to the tax-lot table's `fully_sold` (`frontend/0027` OD-3), and for the opposite reason. **No field is added.** |

## 9. Rollout & observability

Additive: every existing path still resolves, so a client built before this
renders unchanged. No flag, no migration, no new log event. `make catalog`
regenerates both artefacts and the gate diffs them.
