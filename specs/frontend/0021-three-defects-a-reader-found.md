# 0021 — Three defects a reader found

- **Area:** frontend (the allocation legend, the Assistant's route, the catalog's chrome)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for these; none is invented here_
- **Also:** [frontend/0009](0009-holdings-and-activity-tabs.md) OD-3 (the hand-off that stopped working), [frontend/0016](0016-component-catalog-gallery.md) (the catalog), [frontend/0026](0016-component-catalog-gallery.md) *(allocation legend metrics)*, [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-5 (go_router)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

Three things the TL hit in the running app in one sitting. None was caught by
a gate, and each was a different kind of blind spot.

1. *"Los datos están muy tirados a la izquierda, los de la última columna."*
2. *"Cuando clickeo en estos me lleva al assistant pero no hace nada."*
3. *"Después del catalog no puedo volver para atrás."* — and, from the detail page, *"de acá tampoco."*

## 2. Rulings

- **OD-1 — the legend's figures were left-aligned, and the cause was two
  `flex: 1`s.** `Expanded` (the label) and `Flexible` (the figures) both
  default to a flex of 1, so Flutter split the free space **50/50**; the
  figures' column is a *loose* fit, so it shrank to its content and was packed
  at the **start** of its half. `crossAxisAlignment: end` could not help — the
  Column is already as wide as its widest child, so aligning inside it is a
  no-op. The slot is what had to be filled, and an `Align` fills it.

  MEASURED at 400 px, before: the two rows' figures both began at x = 234.5
  and ended at 334.5 and 322.0 — 65.5 and 78.0 px short of the edge, and not
  level with each other. After: every figure ends at 400.0. The `Flexible` is
  **kept**, so a narrow legend still trims instead of overflowing.

- **OD-2 — the Assistant is a preserved branch, so "send on create" fires
  once.** `ConversationPage` dispatched the route's question inside
  `BlocProvider.create`. The Assistant is a `StatefulShellBranch`, and
  `StatefulShellRoute` keeps each branch's navigator alive: the second time a
  chip navigated to `/ask?ask=…` the branch was restored, the element reused,
  `create` did not run, and the tap opened the Assistant and did nothing. The
  page is a `StatefulWidget` now; the bloc lives in the state and the question
  is dispatched from `initState` and from `didUpdateWidget` when it changes.

  **Known limitation, stated rather than discovered:** tapping the *same*
  chip twice produces no navigation at all — the location is identical, so
  go_router reports nothing and there is nothing for `didUpdateWidget` to see.
  Fixing that means putting a nonce in the URL, which changes a shareable
  link into a disposable one. Not worth it for a demo; recorded here so the
  next person does not spend an afternoon on it.

- **OD-3 — the catalog's two routes are outside the shell, and had no way
  back.** That placement is right: a documentation surface is not a tab. What
  was missing is the consequence — neither page inherits the tab bar, the
  index had no control at all, and the detail page had only an 11 px
  monospace crumb that does not read as one. On the web the browser's back
  button hides this; in the app both pages are dead ends.

  A back control leads the top bar. **Where it goes is the page's answer, not
  `pop()`**: the catalog is reachable from a Home chip and from a Holdings
  card, so what is underneath on the stack is not always what a reader means
  by "back". The index returns Home; a detail page returns to the index — the
  same destination the crumb names, so the two controls on one bar cannot
  disagree.

  `GestureDetector`, not `InkResponse`: the bar is a `Container` with no
  `Material` ancestor (six existing tests went red on that), and every other
  tap target on these surfaces is a gesture detector. An ink ripple here would
  be the only one in the documentation.

- **OD-4 — two files were split to stay inside the budget**, not for taste:
  `allocation_swatch.dart` out of the legend row and `catalog_back_control.dart`
  out of the top bar. Both are named after what they are.

## 3. Acceptance criteria

1. **AC-1** — every figure in the allocation legend ends at the row's right edge, and two rows of different widths share it.
2. **AC-2** — a narrow legend trims a figure rather than overflowing.
3. **AC-3** — navigating to `/ask` with a second, different question starts a second turn.
4. **AC-4** — opening the Assistant tab with no question replays nothing.
5. **AC-5** — a rebuild with the same question does not re-ask it.
6. **AC-6** — the catalog index's back control goes Home; a component page's goes to the index; both announce where they go.
7. **AC-7** — `cd frontend && make gate` green, 100 % line coverage per file.

## 4. Test plan

| AC | How |
|---|---|
| 1, 2 | `holdings_allocation_alignment_test.dart` — geometry, asserted against the legend's own right edge rather than a constant |
| 3, 4, 5 | `app_router_ask_again_test.dart` — the **real router**, because the defect lives in the interaction between the route and the page and neither shows it alone |
| 6 | `catalog_back_control_test.dart` — a router that records where it was sent |
| all | reproduced first: AC-3's suite was written against the old page and **failed**, reporting `All calls: … text: first` |

## 5. Out of scope

- The same-question-twice case (OD-2).
- The `Gemini · A2UI` pill, which names a model the build may not be running: the client cannot know which model answered, and telling it is a contract change plus a product decision. Named in `backend/0036`'s report, not fixed.
