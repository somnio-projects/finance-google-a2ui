# 0002 — A selected bar offers the drill, on the v1.0 wire

**Status:** In progress · **Ticket:** [GGU-161](https://somniosoftware.atlassian.net/browse/GGU-161) · **Area:** `frontend_v1/`
**Pair:** [`backend/0056`](../backend/0056-the-drill-runs-its-tool-without-the-model.md) · **Twin:** [`frontend/0040`](../frontend/0040-a-selected-bar-offers-the-drill.md)

## 1. Problem

Spec 0001 AC-6 says *"Tapping a waterfall bar sends `action(drill_attribution)`"*.
On the deployed v1.0 app it sends nothing for Flow A: the turn draws
`attribution.window.v1`, whose payload declared no drill and whose component
never read one. Where the drill was wired, it fired on the same tap that
toggles the selection, so a second tap meant to deselect drilled again.

## 2. What ships

The twin of `frontend/0040`, copied rather than shared (an app cannot be a
dependency, 0001 §2), with the one v1.0 difference the copy already had:

- **AC-1** — the tap only selects / deselects; it sends nothing.
- **AC-2** — a selected, declared bucket shows `AttributionWaterfallDrill`
  with the declaration's `label`, in both the all-time and the window
  waterfall, through `attribution_waterfall_drill.dart`.
- **AC-3** — pressing it sends `action(drill_attribution)` with
  `context: {driver: <key>}` on `POST /a2ui/v1/a2a`. The payload still
  declares the drill by its v0.9 id; the wire name is
  `drillAttributionAction` from `packages/a2ui_v1` (ADR-M D-7).
- **AC-4** — the backend answers with a `DriverDetail` surface and no model
  call (backend/0056 AC-5); the waterfall stays above it in the transcript,
  which is the way back (backend/0056 OD-3).
- **AC-5** — the bundle's catalog copy (`app/assets/a2ui/finance.catalog.json`)
  is re-synced from `docs/a2ui/v1.0/` by `make catalog` if `make catalog` on
  the backend moved it; nothing in `frontend/` is edited from here.

## 3. Test decision

The same suites as `frontend/0040` §4, run under `frontend_v1/`'s own gate,
asserting the v1.0 action name `drill_attribution`. 100 % line coverage per
file.
