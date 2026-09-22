# 0013 — The multi-leg draft order, as Flow C draws it

- **Area:** frontend
- **Status:** In progress
- **Ticket:** [GGU-108](https://somniosoftware.atlassian.net/browse/GGU-108) (the Flutter half)
- **Also:** [backend/0031](../backend/0031-order-ticket-v2.md) (the contract), [0006](0006-order-ticket.md) (`order.ticket.v1`, whose bloc and round trip this reuses), [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-3/D-14, [`client/0003`](../client/0003-client-backend-contract.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

Spec 0006 OD-1 recorded that the design and the frozen contract were two
different components sharing a name, adopted the design's visual language for
`order.ticket.v1` and left its field inventory — legs, impact, constraints — to
a backend ticket. That ticket is backend/0031, and `order.ticket.v2` now
carries every field the artboards draw. Nothing renders it.

The component the design draws is also the sharpest test of the numbers rule
this client has met. A stepper adds one; a weight slider turns a pixel into a
share count; a `NVDA +$2,000` pill subtracts one amount from another. None of
those is arithmetic the client may perform (N-2), and each has a ruling below.

## 2. What ships

- **`app/lib/components/order_ticket_v2/`** — `OrderTicketV2Component`
  (view `order.ticket.v2`, A2UI `MultiLegOrderTicket`), its card, header,
  leg tile, stepper, weight bar, impact panel, grid, weight row, notice,
  placeholder buttons, the change set, and a measured palette and chrome in
  `order_ticket_v2_tokens.dart` — light and dark, from
  `Catalog_OrderTicket.dc.html`'s `pal()` and inline styles.
- **`app/lib/features/order_ticket_v2/`** — a page and a view over the
  **existing** `OrderTicketBloc` (OD-4), at `/order-ticket-v2`.
- The regenerated component manifest. No hand-written seam file changed; the
  router table gained one route, as v1's did.

Bound at these paths, all from the generated catalog entry:

| Payload path | Used for |
|---|---|
| `title`, `badge`, `side` | the header caption (uppercased — typography, not a rewrite) and the pill |
| `legs` | the option value in effect; the one option an edit sends |
| `lines[].key`, `symbol`, `name` | the leg's identity and screen-reader label |
| `lines[].price.display`, `quantity.display`, `notional.display`, `weight.display` | the leg's figures, verbatim |
| `lines[].weight.value` | **geometry only** — the bar's fill width, through `ViewPayload.geometry` (ADR-L D-14) |
| `lines[].increment`, `decrement` | what `+` and `−` send; `null` disables the side |
| `impact.total`, `units`, `fees`, `cash_remaining` — `label` and `*.display` | the panel's four figures |
| `impact.weight_shifts[]` — `key`, `label`, `before.display`, `after.display` | the `Portfolio weight · Technology  46.57% → 48.52%` row |
| `constraints.breach`, `constraints.message` | the blocked pill, the red cash figure, the notice — verbatim |
| `disclosure` | rendered verbatim in every state (N-9) |

`lines[].price.amount`, `notional.amount`, `impact.*.amount.amount`,
`constraints.max_cash`, `constraints.shortfall` are read by **nothing**; the
shortfall reaches the reader inside the backend's sentence.

## 3. Rulings

- **OD-1 — the weight bar is a display, not a slider.** The design draws a
  handle. Dragging one would map a pixel to a share count and a share count
  to a `legs` string — arithmetic and a template in one move (N-2, N-5). The
  stepper is the control; the bar shows what the stepper did, with the fill
  sized from `weight.value` the way the donut sizes an arc. Raised for
  design: a slider needs the backend to publish the `legs` value for each
  stop, which is a payload gap, not a client decision.
- **OD-2 — the recomputed pill names the leg, not the delta.** `NVDA +$2,000`
  needs the previous amount subtracted from the current one. The client
  compares strings to know *that* NVDA moved (0006 AC-9's mechanism, reused
  as `changedKeys`) and the pill reads `NVDA · recomputed`. If design wants
  the figure, the backend can write it once it is handed the previous `legs`
  — an option, and a payload gap raised under N-3.
- **OD-3 — `Review order` and `Save as draft` are honest placeholders.** The
  contract declares no action (backend/0031 OD-9), so both are drawn
  **disabled**, in the colours the catalog page gives a button that cannot
  be pressed (`#d8d5e2` on `#9a97a8`, dark `#2a2b33` on `#6a6b74`), each
  telling a screen reader *Not available in this showcase*. The disclosure
  under the card says the rest. A live-looking button on a surface whose own
  disclosure says nothing is ever placed is the bug 0006 OD-2 refused to
  ship; drawing the design's affordance dead is the honest middle.
- **OD-4 — `OrderTicketBloc` is reused, not copied.** It owns an options map
  and a single-view, debounced re-request, and takes the view id by
  injection precisely so a second ticket needs no second bloc. The page hands
  it `order.ticket.v2` and the view forwards the stepper's string as the
  `legs` option. Its own route, for v1's reason: one flat option set per
  request (N-7).
- **OD-5 — the catalog page wins where the flow disagrees.** Dark `Review
  order` is `#7a83ff` on the catalog page and `#b9c0ff` in Flow C; the weight
  row's dark fill is `#15161c` against `#101017`. The component page is the
  contract and the flow is one placement of it — the side 0006 AC-16 took.
- **OD-6 — the stepper cells are the catalog's 26 px**, not the flow's 28;
  same reason.
- **OD-7 — a busy ticket holds its steppers.** While a re-request is in
  flight the previous figures stay on screen (0006 AC-8) and both sides of
  every stepper are disabled, so a second tap cannot race the first: the
  string it would send was written for a draft that no longer exists.

## 4. Test decision

Component: every display string bound verbatim and no raw member on screen;
the disclosure in every state; read-only without a host; a missing field
raised, not reconstructed; `register` adds exactly one. Contract, against the
snapshot: `legs` is a declared option and a payload field of the same name,
`lines[]` round-trips nothing, every stepper value matches the declared
pattern, the blocked state is a declared field. Change set: first render,
unchanged, one figure, a stepped leg and its slots, a weight row, a slot the
previous render lacked. Widgets, light and dark: the card's measured chrome
as rendered and phone/desktop widths; `+` and `−` sending the backend's
strings unchanged and a `null` side disabled; the stepped leg's tint; the
panel's marks, caption and tint; the blocked notice and red cash; the pills;
the disabled buttons' chrome and hint; every token as a literal. Feature: the
request carries the catalog's view id alone; a real `+` tap reaches the
repository as `legs=<increment>`; marks after a step; steppers held in
flight; a refused step shown over the ticket; an unreadable previous payload
marks nothing; the route. 100 % line coverage per file, under the gate.
