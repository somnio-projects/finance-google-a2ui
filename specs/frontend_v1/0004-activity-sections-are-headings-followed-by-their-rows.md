# 0004 — Activity sections are headings followed by their rows, on the v1.0 client

**Status:** In progress · **Ticket:** GGU-166 · **Area:** `frontend_v1/` · **Twin:** [`frontend/0042`](../frontend/0042-activity-sections-are-headings-followed-by-their-rows.md)

## 1. Problem

Since GGU-157 ([`frontend/0039`](../frontend/0039-activity-rows-and-the-position-hand-off-are-reachable.md)) every Activity row has its own semantics node, but the dated section labels were still loose `Text`s. They merged into the nearest ancestor node, so every label was joined into one name ("TODAY THIS WEEK NOVEMBER 2026 ...") with the rows after it as content. The Activity timeline is a verbatim copy in `frontend_v1/`, so the defect is identical.

## 2. Decisions

Same as the twin spec, applied to `frontend_v1/app/lib/features/activity/view/activity_sections.dart`:

| # | Decision |
|---|---|
| OD-1 | Each section label is `Semantics(container: true, header: true)` with only its own payload text. |
| OD-2 | Reading order is the `Column` order: header, its rows, next header. Pinned by the test. |
| OD-3 | Row wrapper from GGU-157 unchanged; every row stays exposed after a filter change. |

## 3. Acceptance criteria

- AC-1: each header is a separate `isHeader` node with only its own label.
- AC-2: traversal order is header, that section's rows, next header.
- AC-3: after a filter change every row and header is still exposed.

## 4. Tests

`frontend_v1/app/test/features/activity/view/activity_semantics_test.dart`, the same two assertions as the twin. 100 % line coverage holds.

## 5. Not verified

A real screen reader or the browser accessibility inspector on the deployed app.
