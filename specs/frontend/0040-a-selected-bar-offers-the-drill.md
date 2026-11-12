# 0040 — A selected bar offers the drill; the drill is a button, not the tap

- **Area:** frontend (A2UI v0.9)
- **Status:** In progress
- **Ticket:** [GGU-161](https://somniosoftware.atlassian.net/browse/GGU-161)
- **Also:** [backend/0056](../backend/0056-the-drill-runs-its-tool-without-the-model.md) (the window walk declares the drill; the drill runs `driver_detail` with no model), [0011](0011-the-assistant-as-designed.md) OD-4 (the tap), [0014](0014-flow-a-drill-down.md) (the driver card), [0028](0028-the-waterfall-matches-the-ui-kit.md) (GGU-119's selected state), [frontend_v1/0002](../frontend_v1/0002-a-selected-bar-offers-the-drill.md) (the same change on v1.0)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-11-12

## 1. Problem

Two things kept GGU-31 AC-1 from happening on the deployed Assistant:

1. Flow A's turn draws `attribution.window.v1`, and
   `AttributionWindowComponent` never read `actions` — its doc said *"No
   drill"*, which was true of the payload at the time (backend/0056 §1).
2. Where a drill *was* wired (`attribution.waterfall.v1`), it fired on the
   **same tap** that toggles GGU-119's selection: the first tap selected and
   drilled at once, and the second tap — meant to deselect — drilled again.
   A selection that is also a send cannot be looked at before it is acted on.

## 2. What ships

- **AC-1 — the tap only selects.** First tap on a bucket selects it and shows
  its detail (strip or callout, as now); a second tap on the same bar
  deselects; a total clears. The tap sends nothing.
- **AC-2 — the selected bucket offers the drill.** When the surface sits in a
  `SurfaceActions` scope **and** the payload declares `drill.attribution.v1`
  **and** the selected key is among its `choices`, the card shows
  `AttributionWaterfallDrill` under the chart (and under the strip on a
  phone): a button whose words are the declaration's own `label`
  (*Break this down*, N-9) and whose semantics name the bucket
  (`identityLine`).
- **AC-3 — pressing it sends the action.** `SurfaceActionRequest(
  'drill.attribution.v1', {driver: <key>})` through the scope, once per
  press. The agent answers with `attribution.driver.v1` (`DriverDetail`).
- **AC-4 — both registrations of the waterfall.** The all-time and the
  window components bind the drill through one helper
  (`attribution_waterfall_drill.dart`); the window component no longer
  claims it has none. A `7d`/`30d` window declares `actions: []` and so
  shows no button (backend/0056 OD-2).
- **AC-5 — the way back is the transcript.** The drill is a new turn below
  the waterfall; the waterfall stays above it, selected, and its button still
  works (backend/0056 OD-3). No *Back* control is drawn.

## 3. Rulings

- **OD-1 — the button carries the backend's label.** A Dart constant
  (*See what drove this*) would not follow the view's locale and would be a
  second name for one action; the declaration already publishes `label`.
- **OD-2 — one placement for both layouts.** The desktop callout is an
  overlay inside the chart's gesture area, so a control inside it would
  compete with the bar's own tap. The drill sits in the card's flow, under
  the chart (wide) or under the strip (narrow) — the same widget in both.
- **OD-3 — outside the Assistant nothing changes.** No scope, no button; the
  card selects exactly as GGU-119 shipped it.

## 4. Test decision

Card: tap selects, re-tap deselects, a total clears, and **no** callback
fires on any tap; the button appears only for a declared, selected key and
sends that key once per press, in both layouts. Components: both read the
declaration; an undeclared surface or a missing scope draws no button.
Conversation: tap the bar, then the button, and the bloc starts one turn with
`drill.attribution.v1`. Goldens unchanged (no scope in a golden). 100 % line
coverage per file, as the gate requires.
