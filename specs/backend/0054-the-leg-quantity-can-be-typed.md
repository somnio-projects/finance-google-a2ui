# 0054 — The leg quantity can be typed

**Status:** In progress — requested by Patricio Burzaco (PM) 2026-10-06, approved by the TL · **Ticket:** *unassigned* · **Area:** `backend/` (contract) + `frontend/` + `frontend_v1/` (the one widget both apps share)

## 1. Problem

On `order.ticket.v2` the quantity between `−` and `+` can only be stepped. To
buy "0.31 BTC" a person taps dozens of times. The PM asked, before the demo,
for the number to be typeable. The client may not compute a `legs` value
(N-2): `+` and `−` already carry the whole value the backend wrote.

## 2. Scope

**In:** one payload field, `lines[].entry` — the `legs` option value with this
leg's units replaced by the placeholder `{units}`. The stepper's count becomes
a text field in **both** apps: on submit (Enter or tapping outside) the client
puts the typed text in the hole **verbatim** and re-renders through the same
edit path the stepper uses (REST re-render on v0.9, `callAgentFunction(renderView)`
on v1.0).
**Out:** any client-side validation (N-8) — a malformed entry is the options
model's 422 / `INVALID_FUNCTION_CALL`, exactly as for a hand-written URL.

## 3. API contract

`OrderLine.entry: str` (≤ `MAX_LEGS_TEXT`), e.g. `"BTC:{units},ETH:1.0,SOL:16"`.
Built by `app.domain.draft_entry.entry_template`. Braces cannot occur in a
`legs` value, so a template is never itself a valid option. Regenerated:
`docs/catalog/CONTRACT.md`, `view-catalog.snapshot.json`,
`docs/a2ui/v1.0/examples/surface.order_ticket_with_payoff.json`.

## 5. Security notes

The typed text reaches the backend only as an option value, validated by
`LEGS_PATTERN` and the units bound before any work. Nothing new is logged.

## 6. Acceptance criteria

- **AC-1** Every rendered leg carries `entry`, with exactly one `{units}` hole
  in that leg's place; substituting a valid quantity yields a value
  `parse_legs` accepts.
- **AC-2** Submitting a typed quantity sends `entry` with the hole filled by
  the trimmed text, unparsed; submitting the value on screen or blank text
  sends nothing.
- **AC-3** The field is read-only when the payload carries no `entry` or no
  host can honour an edit; a new render resets it to `quantity.display`.
- **AC-4** `frontend/` and `frontend_v1/` carry the identical widget.

## 7. Test plan

`tests/unit/domain/test_draft_entry.py` (AC-1);
`order_ticket_v2_quantity_field_test.dart` in both apps (AC-2, AC-3); the
catalog drift gate for the regenerated artefacts.
