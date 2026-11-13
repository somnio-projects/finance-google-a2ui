# 0041 — The drill button is its own accessible node

- **Area:** frontend (A2UI v0.9)
- **Status:** In progress
- **Ticket:** [GGU-165](https://somniosoftware.atlassian.net/browse/GGU-165)
- **Also:** [0040](0040-a-selected-bar-offers-the-drill.md) (the button), [0039](0039-activity-rows-and-the-position-hand-off-are-reachable.md) (GGU-158, the same defect on the Holdings hand-off), [frontend_v1/0003](../frontend_v1/0003-the-drill-button-is-its-own-accessible-node.md) (the same change on v1.0)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-11-13

## 1. Problem

QA found that after a bar is selected, "Break this down" appears in the
semantics tree as a button whose bounds are the **whole waterfall card**
(400x496 at 1440 wide). Activating it through accessibility sends no
`drill_attribution`; a pointer tap on the painted button works.

Cause: `AttributionWaterfallDrillButton` wrapped its `TextButton` in
`Semantics(button: true, excludeSemantics: true)` **without `container`**. A
semantics node that is not a container merges into the nearest ancestor
that is, so the button's flags and label were folded into the card's node
(rect = the card) and the tap action stayed on the inner `TextButton`, which
the merge no longer reaches. The same defect, in the same shape, as the
Holdings hand-off fixed by GGU-158 (spec 0039).

## 2. What ships

- **AC-1** — the drill button is its own semantics node: `container: true`,
  role button, label `<label>, <identityLine>`, bounds limited to the button.
- **AC-2** — that node carries an explicit tap action that calls the same
  `onPressed` as the pointer tap, so a screen-reader activation sends exactly
  one `drill.attribution.v1` and the transcript draws `DriverDetail`.
- **AC-3** — the chart's own semantics (title, net, the selected bucket's
  detail strip or callout) stays separate and readable; the card's node no
  longer carries the button's label.

## 3. Test decision

Widget tests in `attribution_waterfall_drill_semantics_test.dart`: the node
exists with the button flag and the bucket-naming label, its rect is
smaller than the card's, `tester.semantics.tap` sends exactly one key, no
ancestor is a button, and the chart's title and selected-bucket text are
still reachable and do not contain the button's label. 100 % line coverage
per file, as the gate requires.
