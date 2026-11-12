# frontend/0039 — Activity rows and the position hand-off are reachable by assistive technology

**Ticket:** GGU-157, GGU-158 · **Status:** In progress

Number 0039 because 0037 is taken by the sign-in fixes (#184) and 0038 is reserved for the startup/routing fix.

## 1. Problem

Two accessibility defects, identical in `frontend/` (A2UI v0.9) and `frontend_v1/` (v1.0):

- **GGU-157.** On Activity, after a filter chip is tapped the semantics tree kept only the simulation note; rows were visual only. A timeline row was a bare `Container` of loose `Text`s with no semantics node of its own, so a whole scroll section collapsed into one merged blob that an accessibility tree does not expose as rows.
- **GGU-158.** In an expanded Holdings position, the card carried `Semantics(button)` around everything, the hand-off included. A button's descendants are presentational on the web, so `Ask the assistant about this` lived inside the card's node and an assistive activation reached the card's tap (collapse) instead of opening the assistant.

## 2. Decisions

| # | Decision |
|---|---|
| OD-1 | `ActivitySections` wraps each `ActivityEntryTile` in `Semantics(container: true, label: …)` over an `ExcludeSemantics` visual. The label is `activityEntryLabel(entry)`: title, detail, term badge, amount and realised line or badge, **each exactly as the payload carries it**, only joined with commas. No formatting, no arithmetic (N-3/N-4). |
| OD-2 | The position card is no longer a button as a whole. Its `GestureDetector` is `excludeFromSemantics`; the **head** is the button (`name` + `value.display`, `onTap` = expand/collapse); the details, and so the hand-off, are siblings. |
| OD-3 | `PositionAsk` is `container: true`, `button: true`, labelled `ask_label`, with an explicit semantic `onTap` that opens the assistant with `ask.text` (the previous `excludeSemantics` had dropped the gesture's tap action from the node). |

## 3. Acceptance criteria

- AC-1: after a filter change every rendered row has a semantics node whose label contains its title, detail, amount and badge.
- AC-2: the hand-off has its own node, role button, label `ask_label`; none of its ancestors is a button.
- AC-3: a semantic tap on it opens the assistant with the row's `ask.text` and does not toggle the card.
- AC-4: a semantic tap on the card's head still toggles it.

## 4. Tests

`activity_semantics_test.dart` (filter change through a pending request and the cross-fade, then every row asserted) and `position_ask_semantics_test.dart` (`tester.semantics.tap`), in both apps. 100 % line coverage per file holds.

## 5. Not verified

The failure was observed in a browser's accessibility tree; the VM semantics tree already exposed the rows in the old code after a settle, so AC-1's test pins the contract (one labelled node per row) rather than reproducing the web symptom. A check with a real screen reader or the browser's accessibility inspector on dev is still owed.
