# 0003 — The drill button is its own accessible node, on the v1.0 wire

**Status:** In progress · **Ticket:** [GGU-165](https://somniosoftware.atlassian.net/browse/GGU-165) · **Area:** `frontend_v1/`
**Twin:** [`frontend/0041`](../frontend/0041-the-drill-button-is-its-own-accessible-node.md) · **Builds on:** [`0002`](0002-a-selected-bar-offers-the-drill.md)

## 1. Problem

The button added by 0002 appears in the semantics tree with the whole
waterfall card's bounds, and activating it through accessibility sends no
`action(drill_attribution)`. Cause (identical to the twin): its `Semantics`
was not a `container`, so it merged into the card's node and its tap action
was lost. See `frontend/0041` §1.

## 2. What ships

The twin's change, copied (an app cannot be a dependency):

- **AC-1** — the button is its own `container` node, role button, labelled
  `<label>, <identityLine>`, bounds limited to the button.
- **AC-2** — it carries an explicit tap action, so assistive activation sends
  the same single `action(drill_attribution)` with `context: {driver: <key>}`.
- **AC-3** — the chart's own semantics stays separate and readable.

## 3. Test decision

The twin's `attribution_waterfall_drill_semantics_test.dart`, copied. 100 %
line coverage per file.
