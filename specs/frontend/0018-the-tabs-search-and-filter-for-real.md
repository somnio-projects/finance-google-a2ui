# 0018 — The tabs search and filter for real

- **Area:** frontend (the client half of [`backend/0035`](../backend/0035-the-portfolio-has-an-owner-and-the-tabs-really-filter.md))
- **Status:** Draft
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [frontend/0009](0009-holdings-and-activity-tabs.md) (the two tabs, and OD-7 which this supersedes), [frontend/0015](0015-loading-states.md), [backend/0028](../backend/0028-holdings-and-activity.md), [ADR-L](../../docs/adr/ADR-L-frontend-architecture.md), [`.claude/rules/frontend/contract-binding.md`](../../.claude/rules/frontend/contract-binding.md) N-6, N-7, N-9, N-10
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

`tab_app_bar.dart` draws the two icons the design puts on the Holdings and
Activity tabs, and both answer a snackbar:

```dart
onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('$label is not part of this preview yet.')),
),
```

`frontend/0009` OD-7 recorded that as deliberate — *"a dead control that
looks live is worse than a labelled one"* — and it was the right call while
there was no option behind it. `backend/0035` declares the options, so the
reason has expired and OD-7 is superseded here.

The Activity chips, by contrast, are **not** stubs and never were: they read
their words from `activity.timeline.v1`'s own `filters` array and post
`kind` back as a declared option. What made them look broken is that the
seeded ledger had one sell in it. `backend/0035` fixes that, and this spec
changes nothing about the chips except to give the same treatment to
Holdings.

## 2. What ships

| Where | Change |
|---|---|
| `app/lib/features/shell/view/tab_app_bar.dart` | the bar takes the controls the tab actually has, instead of two hard-coded dead icons |
| `app/lib/features/shell/view/tab_search_field.dart` | **new** — the search affordance: an icon that expands into a field, and collapses back clearing the query |
| `app/lib/features/activity/bloc/*` | `ActivityQueryChanged`; `query` in the state and in the option map |
| `app/lib/features/holdings/bloc/*` | `HoldingsQueryChanged`, `HoldingsAssetClassChanged`; both in the state and in the positions option map |
| `app/lib/features/holdings/view/holdings_filter_sheet.dart` | **new** — the chips the payload ships, in a modal sheet the filter icon opens |
| `app/lib/features/holdings/view/holdings_view.dart`, `activity_view.dart` | mount the above; render the payload's `empty` sentence when the list came back empty |
| `app/test/**` | the rewritten stub test, the new widget/bloc tests, the debounce test |

## 3. Rulings

- **OD-1 — the search box sends a declared option; it never filters a list
  the client already holds.** N-10 is not negotiable and the mechanism is
  what is checked: `binding_rules_compute_test.dart` needles `.sort(`,
  `.fold(` and `.reduce(` over `app/lib` with no carve-out. It does **not**
  needle `.where(`, so a client-side `rows.where(...)` would compile and pass
  every architecture test — which is precisely why it is written here that
  it is forbidden, and why the reviewer is the check. Each keystroke (after
  the debounce) is a `GET …/views?view=…&query=…`; the rows that come back
  are rendered in the order they arrived.
- **OD-2 — the Activity app bar carries search only.** Its `kind` chips are
  already on screen and already are the filter; a second control setting the
  same option would be two sources of truth for one piece of state, and the
  first person to change one and not the other would ship a lie. `TabAppBar`
  therefore takes its trailing controls as a parameter rather than
  hard-coding them — which is also what makes the Holdings bar able to carry
  two.
- **OD-3 — Holdings' filter is a modal sheet, not a third chip row.** The
  tab already stacks an app bar, a header card with a `By asset class / By
  sector` toggle and a `By position / By asset class` segment. A fourth
  always-visible control row would be the densest screen in the app. The
  sheet's chips are `holdings.positions.v1`'s own `filters` array — the
  **labels are the server's** (N-9); the client spells neither *Equities*
  nor *All*.
- **OD-4 — the search is debounced at 300 ms and a superseded response is
  dropped.** Copied from `OrderTicketBloc` verbatim, including the injected
  `debounce` (so a test does not wait) and the in-flight generation marker
  compared with `identical`, because a slow response to `nv` must not be
  allowed to overwrite the answer to `nvda`. That bug is not hypothetical;
  spec `frontend/0006` OD-6 records it being found.
- **OD-5 — collapsing the search field clears the query.** A hidden filter
  that is still applied is the oldest UI defect there is. The close button
  therefore raises `…QueryChanged('')`, which the bloc sends as *no query*.
  The field is `autofocus` on expand and the icon carries the tab's title in
  its tooltip, so a screen reader is told which list it is about to search.
- **OD-6 — an empty result prints the payload's sentence, not one the client
  wrote.** `positions: []` with `empty: "No holdings match this filter."` is
  a successful render, not a failure state: the bloc stays `success`, no
  `AppFailure` is constructed, and the view binds `payload.text('empty')`.
  The client must not compose *"No results for …"* itself — that is a
  server-written string under N-9, and it is why the field exists.
- **OD-7 — the two tabs still do not use the component seam, and this spec
  does not move them.** `holdings.positions.v1` and `activity.timeline.v1`
  bind `ViewPayload` directly in their feature views; neither is in
  `component_manifest.g.dart`. Registering them would make them reachable
  from the catalog gallery and the Assistant, which is a different decision
  with its own design question, and doing it inside a filter change would
  bury it.

## 4. Acceptance criteria

1. **AC-1** — Tapping the search icon on either tab replaces the title with a
   text field; nothing raises the snackbar, and the string *"is not part of
   this preview yet"* survives only in the Assistant's voice button.
2. **AC-2** — Typing in the Activity search issues exactly **one** request
   300 ms after the last keystroke, carrying `query=` beside `kind=`, and the
   list that renders is the one the server returned.
3. **AC-3** — Typing in the Holdings search does the same for
   `holdings.positions.v1` only; the allocation card is not refetched and
   does not receive `query` (it does not declare it, and one flat option set
   per request means it would 422 the lot — N-7).
4. **AC-4** — The Holdings filter icon opens a sheet whose chips are the
   payload's `filters`; picking one refetches with `asset_class=` and closes
   the sheet; the chosen chip is marked on reopen.
5. **AC-5** — Closing the search field refetches without `query`.
6. **AC-6** — When the server returns an empty list, the tab shows the
   payload's `empty` sentence and the bloc's status is `success`.
7. **AC-7** — `cd frontend && make gate` is green: 150 lines per file
   including tests, `dart analyze --fatal-infos`, and **100 % line coverage
   per file**.

## 5. Test plan

| AC | Test |
|---|---|
| AC-1 | `app/test/features/shell/view/tab_app_bar_test.dart` — the bar renders the controls it is given and none it is not; `holdings_view_test.dart`'s stub assertion is rewritten to assert the field appears |
| AC-2, AC-5 | `app/test/features/activity/bloc/activity_bloc_test.dart` — a fake debounce, three keystrokes, `verify` the repository is called **once** with `{'kind':…, 'query':'nvda'}`; then `''` and `verify` the call carries no `query` |
| AC-3, AC-4 | `app/test/features/holdings/bloc/holdings_bloc_test.dart` — `verifyNever` on the allocation view during a query change; the option map asserted key by key |
| AC-4 | `app/test/features/holdings/view/holdings_filter_sheet_test.dart` — the chips come from the payload, the labels are not literals in `lib/` |
| AC-6 | `activity_view_test.dart`, `holdings_view_test.dart` — empty payload → the sentence, and the state is `success` |
| AC-7 | the gate |

A superseded in-flight response (OD-4) is tested by completing two futures
out of order and asserting the later query's rows are the ones on screen —
the assertion that would be green without the generation marker is written
first and shown red.

## 6. Out of scope

- Registering either tab's projection as a catalog component (OD-7).
- Any search over the Assistant's surfaces or the catalog gallery.
- Persisting a filter across a tab switch or a restart: the bloc is built by
  the page and the filter resets with it, which matches every other control
  on these tabs today.
