# 0006 — The order ticket, and the round trip that recomputes it

- **Area:** frontend
- **Status:** Implemented
- **Ticket:** GGU-61 (the Flutter half of GGU-19) · **Related specs / ADRs:** [ADR-K](../../docs/adr/ADR-K-response-shaping.md) D-3/D-11, [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-3/D-13, [ADR-E](../../docs/adr/ADR-E-money-representation.md), [`backend/0018`](../backend/0018-order-ticket.md), [`frontend/0002`](0002-chart-primitives-and-waterfall.md), [`client/0003`](../client/0003-client-backend-contract.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

`order.ticket.v1` is the catalog's only **interactive** component and the one
the whole showcase argues with. Every other surface can be read; this one is
edited, and an edit changes figures on screen. That makes it the single place
where the product's central claim — *the LLM never computes a financial
figure, and neither does the client* — is either demonstrated or quietly
broken.

The backend has shipped it (spec `backend/0018`): the ticket's editable
parameters **are** its declared options, published in the payload as
`inputs[]` descriptors carrying the bound the options model actually enforces.
Nothing renders them. Until it does, the catalog's most important argument is
a JSON document.

## 2. Scope

**In:**

- `app/lib/components/order_ticket/` — the component binding `order.ticket.v1`,
  its card, its impact panel and its input controls.
- `app/lib/features/order_ticket/` — the bloc that owns the option state,
  debounces edits, issues the **single-view** re-request and surfaces a 422.
- `/order-ticket` in the router table, and nothing else edited there.
- `ViewPayload.strings(path)` — the contract publishes `inputs[].choices` as
  an array of **strings**, which `rows()` cannot read because it requires
  objects. The reader had no accessor for it; this is that accessor, and
  `binding_rules_test.dart`'s literal-path rule now names it.

**No palette role is added.** The design's measured card and panel chrome are
already the app's: `#fdfbff`/`#eae7f0` light and `#15161c`/`#24252d` dark are
`ChartTokens.surface`/`.border` exactly. The highlight (`#eef0ff`/`#cdd2ff`
light, `#20223a`/`#3a3b6e` dark) is the existing `barTotal` accent laid over
the surface at 10 % and 32 %, so it is derived rather than duplicated. One
deviation is declared in §6 AC-16.

**Out:**

- **Submitting an order.** There is no such thing to submit to: the catalog
  entry carries `actions: []` and `effect: "recalculate"`, and the payload's
  own `disclosure` says nothing is ever sent, placed or settled
  (`backend/0018` OD-2). See OD-2 below — the design asks for one.
- **Multi-leg orders, weights, cash and fees.** The frozen contract is a
  single-leg ticket and carries none of those fields. See OD-1.
- `POST /v1/view-renders`. The client has no `POST` at all; the read endpoint
  serves this view with its own options, so a second transport is not needed
  to close this ticket.

## 3. API contract

No HTTP surface changes. The round trip is the **existing** read endpoint,
asked for one view at a time:

| Method & path | Auth | Request | Response | Errors |
|---|---|---|---|---|
| `GET /v1/portfolios/current/views` | Bearer | `?view=order.ticket.v1` + declared options | `PortfolioViewsResponse` | `validation-error → 422`, `not-found → 404` |

Bound at these paths, all of them from the generated catalog entry
(component `OrderTicket`, digest `6cbd19f8949e`):

| Payload path | Used for |
|---|---|
| `title` | the card's heading |
| `symbol`, `name` | the leg's ticker and asset name |
| `side` | the chip in the header, shown as the backend wrote it |
| `size`, `size_in` | **not read as top-level fields.** They are payload fields of the same name as their option — which is what makes them editable, and `order_ticket_contract_test.dart` asserts that equivalence — but the values that reach the screen come from `inputs[].value`, so the component reads them in one place, not two |
| `quantity.display` | the units figure |
| `entry_price.display` | the unit price |
| `notional.label`, `notional.amount.display` | the impact panel's total |
| `inputs[].option` | **which option an edit sends back** |
| `inputs[].label` | the control's label, and its screen-reader label |
| `inputs[].control` | `choice` → a menu, `text` → a field |
| `inputs[].value` | the control's current value |
| `inputs[].choices` | the menu's options — the declared bound |
| `inputs[].pattern` | the field's accepted shape — the declared bound |
| `disclosure` | rendered verbatim, always (N-9) |

`quantity.units`, `entry_price.amount` and `notional.amount.amount` are read
by **nothing**. This component draws no chart, so it has no use for a raw
decimal, and `ViewPayload.geometry` is never called (N-4).

**The option set is sent alone.** The read endpoint applies one flat option
set to every requested view (N-7), and `side` is not an option
`holdings.allocation.v1` declares — so sending it alongside would 422 the
whole request. The re-request therefore carries exactly one view id. That is
the reason this feature has a page of its own rather than living inside
`PortfolioViewsPage`, and it is structural rather than a comment.

## 4. Data model & migration

None. The client has no persistence.

## 5. Security notes

Unchanged, and one prohibition is newly load-bearing. `inputs[].pattern` is a
**server-supplied regular expression**. It is used as a bound to test a value
against, and it is never compiled into anything that can reach code — N-5's
ban on interpreting server strings is what stops the obvious next step. The
values a control offers come from `inputs[].choices`; the client adds no
bound of its own (N-8) and clamps nothing, so the backend's 422 stays the
authority on what is acceptable.

No credential moves. The option values travel in the query string, which is
where declared options belong; the bearer token stays in the header (N-14).

## 6. Acceptance criteria

1. **AC-1** *(ticket AC-1)* — Each editable control maps to the declared
   option of the same name, and an edit sends **only** that option plus the
   options already in effect. Nothing else is sent.
2. **AC-2** — Which fields are editable is **derived, never chosen**: the
   controls are built from `inputs[]`, and every `inputs[].option` is both a
   property of the view's `options_schema` and a payload field of the same
   name. Asserted against `docs/catalog/view-catalog.snapshot.json`, not
   against a list in the test.
3. **AC-3** *(ticket AC-2)* — Changing a parameter re-requests
   `order.ticket.v1` and rebinds. **No figure is derived client-side**: every
   number on screen is a `*.display` string from the response, and the
   component reads no raw member at all.
4. **AC-4** *(ticket AC-3)* — Edits are debounced: rapid changes issue one
   request, carrying the last value.
5. **AC-5** *(ticket AC-4)* — A rejected option (422) surfaces as the
   backend's own `detail`, and the control **keeps the value the user typed**
   — it is not silently reverted.
6. **AC-6** — A `choice` control offers exactly `inputs[].choices` and no
   other value; a `text` control declares `inputs[].pattern` as its accepted
   shape. No bound the schema does not state is invented, and nothing is
   clamped.
7. **AC-7** — The backend being unreachable surfaces as a message, and the
   ticket keeps rendering the payload it already has.
8. **AC-8** — While a re-request is in flight the ticket stays readable and
   the controls are marked busy; the previous figures remain on screen until
   the new ones arrive.
9. **AC-9** — After a successful re-render, the figures whose display string
   **changed** are marked. The mark is a string comparison, never arithmetic.
10. **AC-10** — Without a host that can re-request (the portfolio list), the
    ticket renders read-only. It shows every figure and the disclosure, and
    offers no control it cannot honour.
11. **AC-11** — `disclosure` renders verbatim, in every state including the
    error states (N-9).
12. **AC-12** — Every control carries a screen-reader label taken from
    `inputs[].label`.
13. **AC-13** — The ticket lays out correctly at phone width (390) and at the
    design's desktop width (1024), with a test at each.
14. **AC-14** — Adding this component edited no hand-written component-seam
    file: a directory, `make manifest`, and a feature slice of its own.
15. **AC-15** — `cd frontend && make gate` green, at 100 % line coverage per
    file.
16. **AC-16** — The card and impact panel carry the design's **measured**
    geometry: card radius 16 px and padding `16 × 18`; panel radius 14 px and
    padding `13 × 15`; 1 px borders. Measured off an HTTP render of
    `Catalog_OrderTicket.dc.html` at 1024, in both artboards.
    **One declared deviation:** the panel's 2–3 % fill tint (`#f7f6fc` light,
    `#101017` dark) is not reproduced. It is the one value in the artboard
    that is neither an existing palette role nor derivable from one, and
    buying it would mean a new role on a shared enumeration for a tint that
    the measured 1 px border and 14 px radius already separate. The panel
    uses `surface`.

## 7. Test plan

Test files are named as they shipped. Several suites were split along their
own seams to stay inside the 150-line budget, and this table follows them.

| AC | Test |
|---|---|
| AC-1 | `order_ticket_bloc_test.dart::sends the changed option with the ones already in effect` · `order_ticket_bounds_test.dart::sends the option of the same name when a choice is picked` · `order_ticket_view_test.dart::a real edit on the real control reaches the repository` |
| AC-2 | `order_ticket_contract_test.dart::every editable input names an option the schema declares` · `::every editable input names a payload field of the same name` · `::the editable set is exactly what the payload published` · `::an option the payload does not offer is not made editable` |
| AC-3 | `order_ticket_component_test.dart::binds every display string verbatim` · `::never puts a raw figure on screen` |
| AC-4 | `order_ticket_bloc_test.dart::debounces a burst of edits into one request` |
| AC-5 | `order_ticket_failures_test.dart::surfaces a rejected option and keeps the edited value` · `::a rejection carries the backend problem code, not just a message` · `order_ticket_edit_test.dart::surfaces a rejected edit over the ticket already shown` |
| AC-6 | `order_ticket_bounds_test.dart::offers exactly the declared choices` · `::declares the server pattern and invents no bound` · `::sends an out-of-bounds value rather than clamping it` · `order_ticket_contract_test.dart::a choice offers exactly the values its option declares` · `::a text control declares exactly its option's pattern` |
| AC-7 | `order_ticket_failures_test.dart::surfaces an unreachable backend` · `::keeps the previous payload when a later edit is refused` · `order_ticket_view_test.dart::shows the failure when the first request never lands` |
| AC-8 | `order_ticket_edit_test.dart::keeps the previous figures while a re-request is in flight` · `order_ticket_inputs_test.dart::marks the pending option busy` |
| AC-9 | `order_ticket_impact_test.dart::marks only the figures named as changed` · the `changedFigures` group in the same file · `order_ticket_edit_test.dart::marks the figures the backend changed` |
| AC-10 | `order_ticket_component_test.dart::renders read-only without a host that can re-request` · `order_ticket_inputs_test.dart::disables every control when no host can honour an edit` |
| AC-11 | `order_ticket_component_test.dart::renders the disclosure verbatim` · `order_ticket_card_test.dart::shows a rejection without dropping the disclosure` |
| AC-12 | `order_ticket_inputs_test.dart::labels every control for a screen reader` · `order_ticket_impact_test.dart::announces an updated panel to a screen reader` |
| AC-13 | `order_ticket_card_test.dart::lays out at phone width without overflowing` · `::lays out at the design's desktop width` · `order_ticket_impact_test.dart::stacks the figures when narrow` · `::sets them beside each other when wide` |
| AC-14 | `component_manifest_test.dart` + `catalog_contract_test.dart` (both existing; they extend for free) |
| AC-15 | `cd frontend && make gate` — the gate is the test |
| AC-16 | `order_ticket_card_test.dart::carries the design's measured chrome as rendered` — asserted on the **rendered** `BoxDecoration`, not on the constants, so it goes red if the widget stops using them |

Mutation checks required: **yes** — AC-2 and AC-6 are the interactivity
claim, and a green test there is evidence only if it could have been red.
Three mutations are run and their real output is pasted in the PR: a
hardcoded editable field, a narrowed `choices` list, and a client that
re-validates the server's `pattern` instead of sending the value. The
widened literal-path regex in `binding_rules_test.dart` is mutation-checked
separately, by passing a variable to `payload.strings(…)`.

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | **The design and the frozen contract are two different components sharing a name.** `Catalog_OrderTicket.dc.html` draws a *multi-leg* equity order (NVDA/AVGO/AMD) with `legs[]`, `impact.{total,estShares,estFees,sectorWeightBefore,sectorWeightAfter,cashRemaining}` and `constraints.{maxCash,perLegCapPct}`. `order.ticket.v1` is a *single-leg* crypto ticket (eight tickers) whose only figures are `quantity`, `entry_price` and `notional`. Which is authoritative? | Pato / backend | **The frozen contract**, for this PR. A client cannot invent a payload field (N-3): a leg list, a cash balance and a fee estimate are values only the backend can produce. The design's **visual language and its three states** are adopted; its **field inventory** is not. Raised for GGU-19 — if the design is what ships, `order.ticket.v1` needs a `v2`, and that is a backend ticket. |
| OD-2 | The design's Zone 2 declares `onSubmit()` and draws a **"Review order"** button; Zone 3 instructs *"the user submits via onSubmit; execution is simulated by the backend"*. The contract has `actions: []`, `effect: "recalculate"`, and a `disclosure` that says nothing is ever sent, placed or settled. | Pato / compliance | **No submit affordance is built.** Drawing a button that cannot place an order, on a surface whose own disclosure says nothing is ever placed, is the kind of thing the honesty rule in `.claude/rules/diagrams.md` exists to prevent — a UI must never imply a capability that does not exist. Raised for GGU-19. |
| OD-3 | Zone 3's prompt fragment says *"let the **client** recompute impact on edit"*, and the mock does exactly that (`'$' + l.price.toFixed(2)`, `l.weight.toFixed(0) + '%'`). | Pato / Lautaro | **Not followed, and it should be corrected at source.** This is the one instruction in the corpus that contradicts the product invariant GGU-61 exists to demonstrate, and `binding_rules_test.dart` bans the mechanism outright. A mock computing its own numbers is unremarkable; a **system-prompt fragment** telling the real client to do it is a defect, because it ships to the model. Raised for GGU-19. |
| OD-4 | How does an edit reach a repository, when a component may not import a feature and only a `*_page.dart` may resolve one? | Lautaro | **The waterfall's precedent, unchanged**: the card exposes an optional callback, the component passes none, and a host that can honour it constructs the card itself. `OrderTicketPage` is that host. No new mechanism, and `ViewComponent`'s signature is untouched. **Amended by [frontend/0026](0026-the-ticket-in-the-assistant-is-editable.md) OD-2 (GGU-113):** the component now reads a `SurfaceEdits` scope and passes its callback when one is above it, so the Assistant's transcript — which goes through `ComponentHost` and cannot construct the card — is a host too. Without a scope the component still passes none. |
| OD-5 | Where does the re-request live, given one flat option set per request (N-7)? | Lautaro | **Its own page and bloc**, requesting exactly one view id. Putting it in `PortfolioViewsBloc` would send `side` to every view in the batch and 422 all of them. |
| OD-7 | `inputs[].choices` is read strictly (`strings`) while `inputs[].pattern` is read leniently (`optionalText`), although the catalog gives both a default (`[]` and `null`). Why the asymmetry? | Lautaro | **Deliberate, and narrow.** A missing `pattern` is a `choice` control, which is the normal case and must not fail. A missing `choices` on a control the backend called a `choice` is a menu with nothing in it — indistinguishable on screen from a design decision, and the reader would simply be unable to edit that field. The backend serialises both today, so neither path is live; if it ever renders with defaults excluded, the strict read is the one that tells us, loudly, rather than shipping a dead control. |
| OD-6 | Debounce interval? | Lautaro | **300 ms**, trailing. Long enough that a menu change and a keystroke burst coalesce, short enough to stay inside the ticket's p95 < 150 ms warm budget end to end. It is a constructor parameter so a test drives it explicitly rather than sleeping. |

## 9. Rollout & observability

No flag. The component registers itself and appears in the portfolio surface
read-only; the interactive surface is `/order-ticket`. No metric is added —
the client emits none today.
