# 0026 — The ticket in the Assistant is editable

- **Area:** frontend (the conversation bloc and transcript, the two order-ticket components, one new scope under `components/`)
- **Status:** In progress
- **Ticket:** GGU-113
- **Also:** [frontend/0011](0011-the-assistant-as-designed.md) OD-4 (a surface's tap becomes a turn), [frontend/0025](0025-failures-have-a-way-out.md) (the branch this stacks on), [frontend/0006](0006-order-ticket.md) AC-10 / OD-4 (a ticket with no host renders read-only — the ruling this spec gives a host to), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) D-3, D-11
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-24

## 1. Problem

Patricio, product review of the deployed preview, 2026-09-24: asking the
Assistant to *"Buy 10 shares of NVDA"* returns the order ticket, and it
renders **fully static** — no input, no stepper, no side toggle. *"Flow C's
whole premise is prose intent to an editable order ticket. A read-only ticket
turns it into a confirmation screen for whatever the model guessed."*

The ticket asked which layer was at fault. **The client**, and only the
client:

| Layer | Checked | Finding |
|---|---|---|
| Contract | `docs/catalog/CONTRACT.md`, `order.ticket.v1` | `inputs[]` declares `symbol`, `side`, `size`, `size_in` as editable, with control, choices, pattern and hint. Correct. |
| Payload | `fetchSurfaceEntry` | A render intent is resolved through the **same** read endpoint a `?view=` request uses, so the surface the agent asked for carries the same `inputs[]` block. Correct. |
| Client | `OrderTicketComponent.build` | Built `OrderTicketCard(data: read(payload))` and nothing else. The card renders its controls read-only when `onOptionChanged` is null — by design (0006 AC-10: never offer a control the host cannot honour) — and `ComponentHost` gave the component nothing to honour an edit with. The standalone `/order-ticket` page attaches its own bloc; the Assistant attached nothing. |

The component's own doc comment said so: *"the card exposes a callback and
`build` passes none."* That sentence was accurate and was the bug.

## 2. Rulings

- **OD-1 — an edit re-requests the view; it does not open a turn.** ADR-K
  D-11 says exactly this, and the standalone page already does it: the edited
  option is merged into the options the surface was rendered with and the
  **same view** is fetched again through the read path. The ticket's AC-2
  says "emits an action back to the agent"; that is the mechanism of
  `SurfaceActions` (0011 OD-4), which is for a **tap** that starts a turn. An
  edit is not a question for the model — the declared option is the whole
  message, and the endpoint that answers it validates the value against the
  registry that declared it (D-3). Running a turn per keystroke would also
  re-run tools whose effects are already on screen (frontend/0019 §5). The re-rendered
  ticket is the backend's, so the edit round-trips and is not local state.

- **OD-2 — `SurfaceEdits`, the scope the host puts around an editable
  surface.** The counterpart of `SurfaceActions` for the other half of D-11:
  `onOptionChanged(option, value)`, plus the host's answer to the last edit —
  `pendingOption` and `rejection`. A component reads it with `maybeOf` and,
  finding one, renders its declared inputs live; finding none, read-only, as
  before. No component names an option: `OrderTicketComponent` forwards
  whatever `inputs[]` declared, `OrderTicketV2Component` forwards its one
  option, `legs`. Adding the scope edits no registry and no manifest.

- **OD-3 — the surface remembers what it was rendered with.** `AgentSurface`
  carries `options` (the agent's intent, then every edit since — written on
  the edit itself, not on the answer, so a second edit made while the first
  is in flight merges onto the newest intent and the first is not silently
  undone; review caught the half-ported version of this rule),
  `pendingOption` and `rejection`, and three named transitions —
  `editing`, `rendered`, `refused` — so the bloc reads as the machine it is.
  Entries are only ever appended, so an entry's index names the same surface
  for the life of the transcript; `ConversationSurfaceEdited(slot, option,
  value)` uses it. The edit's in-flight options are compared **by identity**
  when the answer lands, so a slow re-render cannot overwrite a newer edit —
  the rule `OrderTicketBloc` and `HoldingsBloc` already keep.

- **OD-4 — a refused edit is the backend's sentence under the previous
  ticket (AC-3).** A size that is not a number is a 422 problem document from
  the read endpoint; the client shows its `detail` verbatim in the card's
  notice and keeps the last payload. It validates nothing itself (N-8): the
  bound lives where the option is declared. The detail is shown for **every**
  failure of the read, including a `dependency-unavailable` — the same choice
  the standalone `OrderTicketBloc` makes, and unlike the turn notice of 0025
  OD-4, because a 422's detail *is* the copy: it names the bound that was
  crossed, and nothing else could.

- **OD-5 — the text control commits on submit, so no debounce.** The v1 text
  field fires `onFieldSubmitted`, not `onChanged`; a choice fires once. The
  standalone bloc debounces because its page was written for a field that
  changed per keystroke; the transcript needs none.

## 3. Acceptance criteria

1. **AC-1** — an `order.ticket.v1` surface in the transcript renders every declared input as a live control; `order.ticket.v2` renders its steppers live.
2. **AC-2** — changing a control re-requests that view with the agent's options intact and the edited option merged; the re-rendered ticket replaces the entry in place, and the option is marked busy until it does.
3. **AC-3** — a refused edit keeps the previous ticket and shows the backend's sentence under it; an answer without the view is a refusal, not a blank.
4. **AC-4** — a widget test renders the ticket **from an agent-streamed surface** and asserts the controls are editable and the edit round-trips.
5. **AC-5** — a slow answer to an older edit never overwrites a newer one; an index that is not a surface is ignored.
6. **AC-6** — outside the transcript and the standalone page nothing changes: the catalog's live card still renders read-only.
7. **AC-7** — `cd frontend && make gate` green, 100 % line coverage per file.

## 4. Test plan

| AC | How |
|---|---|
| 1, 6 | `order_ticket_component_edits_test.dart`, `order_ticket_v2_component_edits_test.dart` — the component inside and outside a `SurfaceEdits` scope; `surface_edits_test.dart` for the scope itself |
| 2, 3, 5 | `conversation_surface_edit_test.dart` — the bloc, with a `ProblemFailure` for the refusal and two `Completer`s for the race |
| 4 | `assistant_order_ticket_test.dart` — the page, a scripted `AgentSurfaceReady` for the ticket, a real choice change, `fetchPortfolioViews` verified with `{symbol, side}` |

## 5. Out of scope

- `changedFigures` (the highlight of figures that moved) in the transcript. The standalone page derives it from the previous payload; the transcript could too, later, without a contract change.
- Multi-leg ordering beyond `order.ticket.v2`; placing an order.
- Mobile/desktop goldens of the editable ticket in the chat (GGU-113 AC-5): the card's layout is unchanged by this spec and is already golden-tested at both widths on its own.
