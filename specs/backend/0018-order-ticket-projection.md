# 0018 — `order.ticket.v1`: the proposed order as a bindable, editable ticket

- **Area:** backend
- **Status:** Draft
- **Ticket:** GGU-41 · **Related specs / ADRs:** 0005 (presentation layer), 0014 (payoff tool), 0013 (simulate_sale), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md) · rule `.claude/rules/backend/presentation.md`
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

Flow C ends on an order ticket: the user has decided what they might buy or
sell, and the surface has to show the order — asset, side, size, entry price,
what it is worth — with the parameters they can still change. Spec 0014 built
the arithmetic beside it (`payoff`, `order_quantity`) and deliberately shipped
no projection for it (0014 OD-7). The registry holds two projections, both
read-only renderings of what already exists; nothing in it describes an order
that does not exist yet, and nothing in it has an **input**.

That last word is the whole difficulty. A projection is a pure function
*(domain result, options) → DTO* (ADR-K D-6). It produces a payload; it has no
event loop, no state and no way to receive a keystroke. An order ticket is the
catalog's only interactive component, and this spec has to say what
interactivity means inside that model — without inventing a second mechanism,
and without the payload implying that pressing something places a trade, which
in this showcase it cannot.

## 2. Scope

**In**

- `app/presentation/tickets.py` — the vocabulary that makes a surface editable:
  `TicketInput` (an editable option and the bound it carries), `declared_inputs`
  (built from the options model's **own** JSON schema), and the `QuantityDisplay`
  / `MoneyDisplay` pairs a ticket needs (`quantity`, `price`).
- `app/presentation/order_sizing.py` — `OrderTicketOptions`: the declared,
  bounded options a caller may send, and `units()`, how a size becomes a unit
  count. The presentation twin of `app/agent/tools/payoff_order.py`, split off
  for the same reason (file budget, along a seam that was already there).
- `app/presentation/views/order_ticket.py` — the projection: id, DTO, pure
  `render`, A2UI adapter, `fitness` and its `register(...)` call.
- `app/domain/orders.py` — `order_notional`, the mirror of `order_quantity`.
  What an order is worth is a financial statement, not a way of printing one
  (ADR-K D-6), so it lives beside the division, not in the presenter.
- `app/presentation/prompt.py` — one branch for a pattern-bounded **string**
  option (OD-6).
- Tests for all of the above, including the registry-wide check that a
  published input bound is the enforced one.

**Out**

- **Placing an order.** There is no broker, no execution, no order resource and
  no `POST` anywhere in this spec. OD-2.
- **Position context** — what is already held, whether a sale could be filled,
  which lots it would touch: `simulate_sale` (spec 0013) owns that question and
  duplicating half of it here would give two surfaces two opinions about one
  sale (spec 0014 OD-11). OD-3.
- **The payoff curve** beside the ticket: `payoff.curve.v1`, spec 0014 OD-7.
- **A numeric input control** — nothing declares an editable integer yet. OD-4.
- Any client work: the Flutter side binds this payload, it maps nothing.

## 3. API contract

No new HTTP surface. The projection is served by the endpoints every portfolio
projection is served by (`app.presentation.endpoints.PORTFOLIO_ENDPOINTS`), and
appears in `GET /v1/views`, in the `read_portfolio_views` union and in the
generated prompt fragments by registering — no shared file lists it (ADR-K
D-15).

**Declared options** (`OrderTicketOptions`, `extra="forbid"` — anything else is
a 422):

| Option | Type | Bound | Default |
|---|---|---|---|
| `symbol` | enum | the eight curated market-reference tickers | `BTC` |
| `side` | enum | `buy` \| `sell` | `buy` |
| `size` | string | `^[0-9]{1,9}(\.[0-9]{1,8})?$` | `"1"` |
| `size_in` | enum | `units` \| `usd` | `units` |
| `currency` | enum | `USD` | `USD` |
| `precision` | int | 0..8 | `2` |
| `locale` | enum | `en-US` \| `es-AR` \| `de-DE` | `en-US` |

`size` is a **string**, not a number: a decimal that has been through a JSON
float cannot be made exact again (ADR-E D-5, spec 0014 OD-4). `size_in="usd"`
is divided by the entry price server-side, through `order_quantity` — the one
division the model never performs (ADR-K D-5).

**Payload** (`OrderTicketPayload`, `view: Literal["order.ticket.v1"]`):

```jsonc
{
  "view": "order.ticket.v1",
  "title": "Proposed order",
  "symbol": "DOGE", "name": "Dogecoin", "side": "buy",
  "size": "500", "sizeIn": "usd",
  "quantity":    { "units": "3927.729772…", "display": "3927.72977219" },
  "entryPrice":  { "amount": "0.1273",      "display": "$0.1273" },
  "notional":    { "label": "Order value", "amount": { "display": "$500.00", … } },
  "inputs": [
    { "option": "side", "label": "Side", "control": "choice",
      "value": "buy", "choices": ["buy", "sell"], "pattern": null },
    { "option": "size", "label": "Size", "control": "text",
      "value": "500", "choices": [], "pattern": "^[0-9]{1,9}(\\.[0-9]{1,8})?$" }
  ],
  "effect": "recalculate",
  "disclosure": "Illustrative ticket. This showcase has no broker and no execution: …"
}
```

**Amended by GGU-78.** The payload carries `size` and `size_in` as top-level
fields, named **exactly** as the options that set them, because that naming is
what the generated contract reads to report a field as editable (spec 0019
OD-3). Without them the document advertised `symbol` and `side` only — the two
that happened to share a name with a payload field — and said nothing about the
other half of the controls `inputs[]` offers. `quantity` is deliberately *not*
renamed: under `size_in="usd"` it is the size divided by the entry price, so it
is an output of the render and not a value a caller may send back.

`inputs` is the answer to *where does the editability live*. Each descriptor
names a **declared option**, its current value, how to offer it, and the bound
it must satisfy. Editing is re-rendering: the caller sends that option back
with the same `view` — through `?view=` where the endpoint declares the
parameter, through `POST /v1/view-renders` for anything else, or through the
model's render intent — and gets a new ticket. Both paths already validate
against the same options model (ADR-K D-11, D-12), so an edited value is judged
exactly where every other option is judged. The projection stays pure and
handles no event.

Every figure is a pre-formatted `*Display` string from `app.core.display`; the
unit price goes through `price_display`, so a sub-dollar ticker is not quoted
at a precision its own notional contradicts (spec 0014 OD-10).

## 4. Data model & migration

None. Nothing is persisted; the projection is pure and the portfolio is read.

## 5. Security notes

- Auth, rate limits and error shape are the serving endpoints' and are
  unchanged.
- **Input bounds are the security surface here.** The ticket publishes to the
  client the values each field may hold. A published bound that the backend
  does not enforce is a client-side-only validation — the failure
  `.claude/rules/backend/testing.md` records three times, with a form in front
  of it. Two measures: the bound is *derived* from the options model's own JSON
  schema rather than typed a second time, and
  `tests/unit/presentation/test_declared_input_bounds.py` walks the **registry**
  feeding every published bound back through `validated_options` — the call
  both callers make — so the next interactive component is covered the day it
  registers rather than the day someone remembers.
- Every option is bounded and defaulted; an undeclared option, an unknown
  symbol or an out-of-range value is a 422 (ADR-K D-3), never a clamp.
- A rejection names the option, never the value (`resolve.py`), so an echoed
  input cannot become a reflection vector.
- No personal data, no audit event: nothing is decided or recorded here.

## 6. Acceptance criteria

1. **AC-1** — `order.ticket.v1` is registered from its own module and reaches
   the registry, `GET /v1/views`, the OpenAPI union and the prompt fragments
   with no shared file listing it. Removing the `register(...)` call turns the
   suite red.
2. **AC-2** — `render` is pure and prices the order from the market reference:
   symbol, name, side, quantity, entry price and notional, all formatted.
3. **AC-3** — `size_in="usd"` states the units server-side; the model and the
   client never divide.
4. **AC-4** — the figures printed together agree: the displayed quantity times
   the displayed entry price rounds to the displayed notional.
5. **AC-5** — the payload publishes one `TicketInput` per editable option, and
   for **every** published input the advertised bound is the enforced one:
   every advertised choice is accepted, the published pattern is the schema's
   pattern and cannot match unbounded input, and a value outside the bound is
   rejected with a 422. **GGU-78 adds the half that was missing:** every option
   `inputs[]` offers is also a payload field of exactly that name, so the
   generated contract reports it — checked for every projection by
   `presentation/test_declared_interactivity.py`, not for this one by hand.
6. **AC-6** — the symbols the ticket offers are exactly the curated market
   reference; the two declarations are compared by a test.
7. **AC-7** — `locale` and `precision` shape every rendered string.
8. **AC-8** — the payload declares exactly one effect, `recalculate`, carries a
   disclosure saying there is no broker and no execution, and neither the
   payload nor the A2UI props contain a submit action, an endpoint or a
   callback.
9. **AC-9** — the A2UI adapter maps the payload onto one `OrderTicket` surface.
10. **AC-10** — `fitness` is 0 on every portfolio: the selection rule never
    picks a ticket from data alone.

## 7. Test plan

| AC | Unit test(s) |
|---|---|
| AC-1 | `presentation/test_order_ticket.py::test_the_projection_is_registered_and_renders_its_own_example`, `presentation/test_extensibility.py` |
| AC-2 | `presentation/test_order_ticket.py::test_render_prices_the_default_order_from_the_market_reference` |
| AC-3 | `presentation/test_order_ticket.py::test_a_dollar_size_is_divided_by_the_price_here_not_by_the_model`, `domain/test_orders.py` |
| AC-4 | `presentation/test_order_ticket.py::test_the_three_figures_printed_together_multiply_back_to_one_another`, `domain/test_orders.py::test_sizing_and_pricing_an_order_close_on_each_other_to_the_cent` |
| AC-5 | **`presentation/test_declared_input_bounds.py`** (whole file), `presentation/test_tickets.py` |
| AC-6 | `presentation/test_order_ticket.py::test_the_symbols_a_ticket_offers_are_exactly_the_market_reference` |
| AC-7 | `presentation/test_order_ticket.py::test_render_formats_every_figure_under_the_requested_locale` |
| AC-8 | `presentation/test_order_ticket.py::test_the_ticket_declares_one_effect_and_no_way_to_place_an_order` |
| AC-9 | `presentation/test_order_ticket.py::test_surface_maps_the_payload_onto_the_ticket_component` |
| AC-10 | `presentation/test_order_ticket.py::test_the_ticket_is_never_chosen_by_the_selection_rule` |

Integration: none of its own — the projection is pure and reaches HTTP through
the endpoints spec 0005 and 0012 already cover.

Mutation checks required (auth / rate limit / error masking): **no** — this
change touches none of them. The wiring mutation check (AC-1) was run:
commenting out `register(...)` fails
`test_the_projection_is_registered_and_renders_its_own_example` and every case
in `test_declared_input_bounds.py`.

## 8. Open decisions

| # | Question | Owner | Resolution / default |
|---|---|---|---|
| OD-1 | **Where does editability live in a model whose `render()` is a pure function?** | TL — **in the declaration, not the render** | A projection produces a payload and never receives an event, so the ticket cannot "handle" an edit. But it does not need to: ADR-K D-3 already gives every projection a bounded, validated options model, and D-11 already routes both the client and the model through it. The ticket's editable fields therefore **are** its declared options, published as `TicketInput` descriptors, and an edit is the caller re-rendering the same view with one option changed. Nothing about ADR-K changes; the mechanism is reused rather than extended. What the payload has to add is only the *declaration* — which option a field maps to, and what it may hold. Two alternatives were rejected: a form schema invented per view (a free-form DSL by another name, ADR-K D-3), and a stateful "ticket session" resource (state the showcase does not need, and a second way to validate an option). |
| OD-2 | An order ticket normally ends in a **Place order** button. | TL — **no affordance exists, and the payload says so** | There is no broker, no execution path and no order resource in this showcase. Three honesty measures rather than one: `effect: "recalculate"` names the only thing the ticket does; `disclosure` says it in words, inside the payload the model copies verbatim; and the A2UI props carry no submit, no endpoint and no callback, so a client cannot be handed a way to place a trade even by mistake. A component that *looked* actionable would be the showcase's worst possible bug — a convincing UI that silently does nothing, or worse, that a future integrator wires to something real. |
| OD-3 | Should the ticket show the position already held in the asset? | TL — **no** | It reads well and it invites exactly the question this surface cannot answer: *can I actually sell that much?* Sufficiency, lot selection and realised gain are `simulate_sale`'s (spec 0013), and a ticket that shows a holding beside a sell order implies it checked one. Same reasoning as spec 0014 OD-11. The composed surface can place the two side by side; the payload does not blur them. |
| OD-4 | `TicketInput` publishes `choice` and `text` controls only — no numeric control. | TL — **ship what a payload renders** | A numeric control would need `minimum`/`maximum` fields that no registered option fills, so no test could bite on them and the first real consumer would inherit an untested bound. The second interactive component adds it, with its test, in that PR (ADR-K D-16). |
| OD-5 | What should `fitness` be? | TL — **0, never auto-selected** | The selection rule (ADR-K D-13) picks a projection from the *data*. A ticket answers an intent — "I am thinking of buying" — which no portfolio expresses. Scoring it above zero would put an order ticket under a question about last month's performance. |
| OD-6 | The prompt fragment described `size` as *"list of names"*. | TL — **one branch in `prompt.py`** | `option_bounds` had no case for a pattern-bounded string, because no projection had one; the fallback then taught the model that a decimal size is a list. This is **not** the D-15 violation it resembles: the registry seam held (nothing lists the view anywhere), and the gap is in a generic schema-to-English renderer that this chart is simply the first to exercise. Three lines, with its case in `test_prompt.py`. Flagged for the integrator as a shared-file touch. |
| OD-7 | Does a `size` of `0` render or fail? | TL — **it renders an empty ticket** | The payoff tool rejects a zero size because a return on nothing is undefined (spec 0014 OD-4); a ticket has no return, so nothing is undefined. More importantly, the published pattern admits `0`, and a bound that advertises what the backend refuses is the same defect as one that advertises less — in the direction that makes the widget's own validation a lie. The pattern is the whole truth about `size`. |

## 9. Rollout & observability

No flag of its own: it is served by `views.read` and `views.batch-render`,
already gated. No migration, nothing persisted. A render intent naming this
view with a bad option is rejected and counted like any other
(`presentation.render_intent.rejected`, spec 0005 AC-9). The projection is a
handful of `Decimal` operations over an eight-row reference list, so it is
comfortably inside the ADR-K p95 budget.

> **Amended 2026-09-21 by spec [0024](0024-contract-serves-the-designs.md)
> (GGU-102).** `order.ticket.v1` **stays single-leg.** The design's
> multi-leg ticket is not a backwards-compatible addition to this payload —
> it is `order.ticket.v2`, raised as GGU-108 and post-demo. The default
> `symbol` is unchanged: see 0024 §3 for why 'use an equity' could not be
> carried out. The page's Zone 3 fragment is **not** transcribed — as
> written it instructs the reader to recompute figures (0024 §5).
