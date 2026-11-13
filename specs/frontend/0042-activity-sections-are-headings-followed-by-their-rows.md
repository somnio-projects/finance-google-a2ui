# frontend/0042 — Activity sections are headings followed by their rows

**Ticket:** GGU-166 · **Status:** In progress · **Twin:** [`frontend_v1/0004`](../frontend_v1/0004-activity-sections-are-headings-followed-by-their-rows.md)

## 1. Problem

Since GGU-157 ([0039](0039-activity-rows-and-the-position-hand-off-are-reachable.md)) every Activity row has its own semantics node, but the dated section labels (`TODAY`, `THIS WEEK`, `NOVEMBER 2026`, ...) were still loose `Text`s. A loose `Text` merges into the nearest ancestor semantics node, so all the labels were joined into one name ("TODAY THIS WEEK NOVEMBER 2026 ...") and the rows came after it as content. A screen-reader user heard every header in one breath, then a flat list of rows, and could not navigate by heading.

## 2. Decisions

| # | Decision |
|---|---|
| OD-1 | Each section label is wrapped in `Semantics(container: true, header: true)`: its own node, flagged as a header, labelled with only its own text (`group.text('label')`, verbatim from the payload). |
| OD-2 | Reading order needs no sort keys: header and rows are consecutive children of one `Column`, so the traversal is header, its rows, next header. The test pins it. |
| OD-3 | The rows keep the GGU-157 wrapper unchanged; filters and search still replace the whole `ActivitySections`, so every row and every header is rebuilt exposed. |

## 3. Acceptance criteria

- AC-1: every section header is a separate semantics node with `isHeader` and only its own label.
- AC-2: in traversal order the sequence is header, that section's rows, next header, and so on.
- AC-3: after a filter change every row (and header) is still exposed (GGU-157 holds).

## 4. Tests

`activity_semantics_test.dart`: the whole labelled traversal of `ActivitySections` is compared with `[header, rows..., header, rows...]` built from the payload, on first load and after a filter change; and the header nodes alone equal the payload's `groups[].label`. In both apps; 100 % line coverage holds.

## 5. Not verified

A real screen reader or the browser accessibility inspector on the deployed app: the tests read the Flutter semantics tree.
