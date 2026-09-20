# 0001 — Frontend skeleton

- **Area:** frontend (`frontend/`)
- **Status:** Implemented
- **Ticket:** GGU-91 · **Related specs / ADRs:** [ADR-L](../../docs/adr/ADR-L-client-architecture.md) (the architecture), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) (the payloads), [ADR-E](../../docs/adr/ADR-E-money-representation.md) (money), [ADR-I](../../docs/adr/ADR-I-client-routing.md) (amended by ADR-L D-5), [`client/0003`](../client/0003-client-backend-contract.md) (the contract, PR #48)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-20

## 1. Problem

The A2UI showcase has a backend that shapes every payload and no client built
to the repository's own standard. `client_flutter/` exists but is still largely
the upstream restaurant-finder sample; it is moving slowly and its `login_bloc`
is a two-second fake (G-1 on PR #49). The TL's decision is to build a parallel
app rather than keep patching that one.

What is missing is not a screen — it is **the skeleton every later ticket
copies**. The backend half of this repository enforces its standards with
tests, a file budget and a gate; the client half enforces nothing, so a
convention there is only as good as the reviewer's memory. This spec delivers a
client whose rules are held by the gate, plus one vertical slice proving the
whole stack works end to end.

## 2. Scope

**In:**

- A new top-level `frontend/`, a pub workspace with one lockfile.
- Four packages: `finance_core`, `finance_api_client`, `finance_views_repository`, `app` (ADR-L D-1).
- A single composition root (`app/lib/bootstrap.dart`), DI by constructor injection (ADR-L D-2).
- `go_router` routing with one auth-gate `redirect` seam (ADR-L D-5), Material 3 theming with an `AppSpacing` `ThemeExtension`.
- `Result` / sealed `AppFailure` / RFC 9457 `ProblemDetails` (ADR-L D-8).
- The HTTP transport: bearer header, repeated `view` query parameters, `ETag`/`If-None-Match`/304, problem-document decoding.
- The component seam: `ViewComponent`, `ComponentRegistry`, `ComponentHost`, and a **generated, gated** manifest (ADR-L D-3).
- **One vertical slice**: `holdings.allocation.v1` fetched, bound and rendered, with tests at every layer.
- The gate: `make gate` (format · analyze · file budget · manifest freshness · tests · coverage), `frontend-ci.yaml`, and the matching `frontend.*` entries in `.claude/ship-gate.json`.
- The harness: `frontend/CLAUDE.md`, `.claude/rules/frontend/*`, a `PostToolUse` hook, a `frontend-reviewer` agent, `SECURITY.md`, a diagram, this spec, the ADR, the harness-log entry.

**Out:**

- The other five catalog components — `attribution.waterfall.v1`, `taxlots.table.v1`, `scenario.comparison.v1`, `payoff.curve.v1`, `order.ticket.v1`. Each is additive by construction (AC-6) and gets its own ticket.
- **Authentication.** A `--dart-define` development token is the only credential path, and it is recorded as a gap (`frontend/SECURITY.md` G-1). ADR-B's force-refresh-once policy is not implemented.
- The A2A streaming surface (`POST /`, `message/stream`) and render intents — spec `client/0003` §8; own ticket.
- `POST /v1/view-renders` batching, the agent chat shell, the component gallery, i18n, golden tests.
- Deployment of the web bundle (`specs/client/0002-client-delivery.md` owns hosting).

## 3. API contract

This client **consumes** a contract it does not define. The source of truth is
[`specs/client/0003-client-backend-contract.md`](../client/0003-client-backend-contract.md)
(PR #48) and `docs/catalog/view-catalog.snapshot.json` (PR #45). What this
skeleton binds:

| Method & path | Auth | Request | Response | Errors (code → status) |
|---|---|---|---|---|
| `GET /v1/portfolios/{portfolio_id}/views` | Bearer | repeated `view` (≤ 4), flat option set | `PortfolioViewsResponse` | `validation-failed → 422`, `portfolio/unknown-view → 404`, `auth/* → 401`, `forbidden → 403` |

Envelope (`RenderedViews`): `as_of` (string, **kept verbatim**), `portfolio_id`
(string), `views` (object keyed by view id → payload).

Payloads are read through `ViewPayload` by dotted path rather than transcribed
into Dart classes — ADR-L D-4, and the reason is in OD-1 below. Errors arrive
as RFC 9457 and are decoded into `ProblemDetails`; call sites branch on `type`
(exposed as `code`), never on `detail`.

`holdings.allocation.v1`, the slice's view, binds: `title`, `total.label`,
`total.amount.display`, and per row `key`, `label`, `value.display`,
`weight.display`. The raw `*.amount` / `*.value` members are **not read** — they
exist for chart geometry, which this skeleton does not draw.

## 4. Data model & migration

None. This client persists nothing: no database, no `SharedPreferences`, no
local cache beyond an in-memory `ETag` map that is dropped on sign-out
(`ViewsRepository.clearCache`). Nothing survives a reload, deliberately — there
is no credential yet that would make a persisted portfolio safe to keep.

## 5. Security notes

Full mapping in [`frontend/SECURITY.md`](../../frontend/SECURITY.md); the
material points:

- The credential is produced in **one** place (`bootstrap.devTokenProvider`) and read in **one** place (`FinanceApiClient._headers`), where it becomes an `Authorization` header. It is never placed in a URL, a query string or a log (N-14, ADR-B D-10) — asserted by a test.
- Failure text shown to the user is the backend's own safe `detail`; no stack trace, no library message, no library exception ever reaches a widget.
- No PII is logged, because the client logs nothing at all yet.
- **Gaps, not claims:** the `--dart-define` token (G-1), no 401/403 retry policy (G-2), no sign-out (G-3), no CSP/SRI on the hosted bundle (G-4), no dependency CVE scan in the frontend gate (G-5). Each carries an owner in `SECURITY.md`.

## 6. Acceptance criteria

1. **AC-1** — `cd frontend && make gate` is green, and runs format, analyze, the 150-line budget, the manifest freshness check, every suite and the coverage threshold.
2. **AC-2** — A file over 150 lines fails the gate. Verified by mutation.
3. **AC-3** — A forbidden import (Flutter under `packages/`, the api client in a bloc, a second construction of `ViewsRepository` outside `bootstrap.dart`) fails `layering_test.dart`. Verified by mutation.
4. **AC-4** — `NumberFormat`, `package:intl`, `dart:math`, `toStringAsFixed`, `double.parse` or `DateTime.now()` anywhere under `lib/` fails `layering_test.dart`. Verified by mutation.
5. **AC-5** — Every public symbol carries a doc comment, enforced by `public_member_api_docs` under `dart analyze --fatal-infos`.
6. **AC-6** — A new component is added by creating one directory and running `make manifest`; **no hand-written file is edited**. A component directory absent from the generated manifest fails the gate. Verified by mutation.
7. **AC-7** — Line coverage is 100 % for every non-exempt file, enforced per file; exemptions are listed with a reason in `tool/check_coverage.dart`.
8. **AC-8** — `holdings.allocation.v1` is fetched, decoded and rendered, and every figure on screen is the backend's `*.display` string byte for byte. A test asserts the raw members do **not** appear.
9. **AC-9** — A 304 resolves to the cached envelope and is treated as success; a 304 with nothing cached is reported, not rendered as empty.
10. **AC-10** — A payload missing a bound field shows a contract violation naming the path, rather than a blank, a zero or a crash (N-3).
11. **AC-11** — A view id with no registered component shows a placeholder; the rest of the surfaces still render.
12. **AC-12** — The bearer token appears only in the `Authorization` header; a test asserts it is absent from the request URL.
13. **AC-13** — `.claude/ship-gate.json`'s `frontend.*` commands are character-identical to the `frontend-ci.yaml` steps and to `make gate`.
14. **AC-14** — `flutter pub get --enforce-lockfile` succeeds from a clean checkout; CI uses the strict flag on every job.

## 7. Test plan

| AC | Unit / package test(s) | Widget / integration test(s) |
|---|---|---|
| AC-1 | — | `make gate` output in the PR body |
| AC-2 | `tool/check_file_budget.dart` (mutation: a 151-line file) | — |
| AC-3 | `app/test/architecture/layering_test.dart` (6 boundary tests) | — |
| AC-4 | `layering_test.dart::nothing formats or computes a number`, `::nothing reads the device clock` | — |
| AC-5 | `dart analyze --fatal-infos` | — |
| AC-6 | `layering_test.dart::every component module registers exactly one component`, `architecture/component_manifest_test.dart` | `component_registry_test.dart::accepts a seventh component without any change to itself` |
| AC-7 | `tool/check_coverage.dart` over four lcov reports | — |
| AC-8 | `finance_views_repository/test/src/view_payload_test.dart` | `holdings_allocation_component_test.dart::binds every display string verbatim`, `::never puts a raw figure on screen` |
| AC-9 | `views_repository_cache_test.dart` (5 tests) | — |
| AC-10 | `view_payload_test.dart` (throws naming the path) | `component_host_test.dart::shows the violation when the payload breaks its contract` |
| AC-11 | `component_registry_test.dart::returns null for a view id it does not serve` | `component_host_test.dart::shows a placeholder when no component serves the view`, `portfolio_views_view_test.dart::separates the surfaces when several are returned` |
| AC-12 | `finance_api_client_test.dart::puts the credential in the Authorization header and nowhere else` | — |
| AC-13 | reading, plus the §5 table in `ci-conventions.md` | — |
| AC-14 | `flutter pub get --enforce-lockfile` in every CI job | — |

Mutation checks required: **yes** — AC-2, AC-3, AC-4 and AC-6. All four were
run for this PR and each turned the suite red before being reverted; the
evidence is in the PR body.

There are no integration tests against a live backend in this PR: the transport
is driven end to end by `MockClient`, and the manual run against the running
stack is the PR's evidence instead.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Component tests bind a **checked-in copy** of the catalog's rendered example, because `docs/catalog/view-catalog.snapshot.json` is on PR #45 and not on `develop`. That copy can drift — the exact failure ADR-L D-4 argues against. | Lautaro | When #45 merges, replace the fixtures with a read of the snapshot and add a test asserting every path a component binds appears in that view's `fields[].path`. Until then the fixtures stay and are labelled in their own doc comments. |
| OD-2 | This app does not yet consume the A2A stream, so render intents never reach it. §8 of `client/0003` offers two consumption strategies (incremental vs. terminal message). | TL | Incremental, matching `client/0003` OD-1, decided when the streaming ticket starts. |
| OD-3 | The backend ships no formatted `as_of`. Showing "valued at …" needs either a display string from the backend (the N-3 answer) or a client-side date format (forbidden by the spirit of N-1). | TL + backend | Do not render `as_of` at all, which is what this PR does. Raise a backend ticket for an `as_of_display` when a screen needs it. |
| OD-4 | Two Flutter apps now exist. If `client_flutter/` is retired, `frontend/` inherits its Jira tickets and its `specs/client/` numbering. | TL | Keep both; `specs/frontend/` numbers this app, `specs/client/` keeps the contract spec shared by both. |
| OD-5 | No dependency vulnerability scan runs over the Dart dependency graph (`SECURITY.md` G-5). | Lautaro | Add OSV scanning of `pubspec.lock` to `frontend-ci.yaml` in a follow-up; the backend's `pip-audit` has no direct Dart equivalent in the toolchain today. |

## 9. Rollout & observability

No feature flag: `frontend/` is not deployed by any pipeline, so merging it
changes nothing that is running. `specs/client/0002-client-delivery.md` owns
hosting when it arrives.

No metrics, no Sentry, no logging in this PR — the client emits nothing. That
is a deliberate floor rather than an omission: the first thing added must be a
reporter that cannot carry a token or a payload, and it lands with the ticket
that needs it.
