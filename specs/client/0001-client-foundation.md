# 0001 — Client foundation (Flutter A2UI client)

- **Area:** client
- **Status:** **Superseded by [repo/0002](../repo/0002-retire-the-client-flutter-app.md)** (2026-09-22)
- **Ticket:** GGU-82 · **Related specs / ADRs:** [ADR-B](../../docs/adr/ADR-B-auth-credential-contract.md), [ADR-D](../../docs/adr/ADR-D-a2ui-streaming-transport.md), [ADR-I](../../docs/adr/ADR-I-client-routing.md), [ADR-J](../../docs/adr/ADR-J-rest-api-and-a2a-surface.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md); [backend/0005](../backend/0005-presentation-layer.md), [backend/0010](../backend/0010-a2a-surface.md), [backend/0019](../backend/0019-frozen-catalog-contract.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-20

> **Superseded 2026-09-22 — the app this spec describes no longer exists.**
> `client_flutter/` was retired in full (directory, gate part, workflow, rules,
> compose file) by
> [`repo/0002`](../repo/0002-retire-the-client-flutter-app.md). This spec is
> kept in place, not deleted: `specs/README.md` says a replaced spec is marked
> `Superseded by NNNN` and stays, so every PR, ADR and rule that cites it by
> number still resolves. Nothing in it binds today.
>
> **What it is replaced by, and what it is not.** The A2UI client this
> repository ships is `frontend/`, specified from
> [`frontend/0001`](../frontend/0001-frontend-skeleton.md) onwards and governed
> by [ADR-L](../../docs/adr/ADR-L-client-architecture.md). That is a different
> app written from scratch, not a continuation of this one — this spec's
> premise was *adapting* Google's restaurant-finder sample, and the project
> chose to rewrite instead.

## 1. Problem

`client_flutter/` is Google's restaurant-finder A2UI sample with the labels
changed. The backend arrived at a paved path — a folder manual, path-scoped
rules, an enforced file budget, a layering contract checked by tests, a
compliance mapping and spec-driven development — and the client got none of
it: seven generic Flutter rules synced from `somnio-ai-tools`, written against
a different repository's layout, and nothing project-specific.

The cost is concrete. Every client question currently ends in reading backend
source: which view ids exist, what a payload carries, whether the client may
format a figure, where a token lives, what a PR must run before it is opened.
The single most important constraint on this codebase —
[ADR-K](../../docs/adr/ADR-K-response-shaping.md), the client transforms
nothing — is written down only from the backend's side, in
`.claude/rules/backend/presentation.md`, where a frontend developer will never
look for it.

This spec is the client's baseline, the counterpart to
[`backend/0001-backend-foundation.md`](../backend/0001-backend-foundation.md).

## 2. Scope

**In (this spec, delivered by GGU-82's `docs(client)` PR):**

- `client_flutter/CLAUDE.md` — the folder manual: stack, run, verify, layout with import direction, what is enforced and what is not, tests, how to add a feature, security posture, do-not-touch.
- `.claude/rules/client/{architecture,presentation,testing,security}.md` — the project rule layer, registered in the root `CLAUDE.md` rules table.
- `specs/client/0001-client-foundation.md` — this file.
- `docs/diagrams/11-client-architecture.md` — the client's layers and trust boundaries, registered in `docs/diagrams/README.md`.

**Out:**

- The Flutter ship gate — `.github/workflows/client-ci.yaml`, the Flutter half of `.claude/ship-gate.json`, the Flutter pre-commit hooks and `client_flutter/tool/check_*.sh`. **GGU-1 owns these** (PR #30). Rules here cite those checks by id and record that they land with GGU-1.
- The app scaffold — everything under `client_flutter/app/{lib,test,android,ios}` and `app/pubspec.yaml`. **GGU-1 owns these** (PR #26).
- Container, hosting and the client's `docs/SECURITY.md` control mapping → `specs/client/0002-client-delivery.md` (GGU-82, `feat(client)` PR).
- The consumed-contract walkthrough with real recorded responses → `specs/client/0003-client-backend-contract.md` (GGU-82, third PR).
- Firebase auth wiring → GGU-2. Today's login is a simulated delay-then-success in `LoginBloc`.
- Any renderer, i18n or design-system work.

## 3. The contract this client consumes

The client is a consumer, so its "API contract" is the backend surface it
binds to. Three entry points, two protocols, two error shapes.

| Surface | Method & path | Auth | What the client does with it |
|---|---|---|---|
| Agent card | `GET /.well-known/agent-card.json` | **none** (ADR-B D-3) | bootstrap: what this agent is, where to post, which A2UI version it speaks. Read before a token exists, which is why it is public |
| A2A | `POST /` (JSON-RPC, `message/stream`, `Accept: text/event-stream`) | Bearer | the agent turn: surfaces stream in as they are ready (ADR-D D-1, D-19) |
| View catalog | `GET /v1/views` | Bearer | discovery: every registered projection with its id, serving endpoints, options JSON Schema and a real example (ADR-K D-8) |
| Portfolio views | `GET /v1/portfolios/{id}/views?view=<id>` | Bearer | a direct read of one or more projections; repeated `view=` batches them into a keyed object (ADR-K D-17) |
| Batch renders | `POST /v1/view-renders` | Bearer | views spanning different resources, with a per-entry status (ADR-K D-18) |
| Sessions | `GET|POST /v1/sessions`, `/v1/sessions/{id}/messages` | Bearer | conversation history |
| Health | `GET /health` | **none** | liveness only; not a client feature |

**Payload contract.** Every projection DTO carries a literal `view` field
(ADR-K D-4) and every figure arrives as a pre-formatted `*Display` string
(D-5); a raw `Decimal` may accompany one for plotting, never replace it. The
frozen field inventory is [`docs/catalog/CONTRACT.md`](../../docs/catalog/CONTRACT.md),
regenerated and diffed by the backend gate — a projection cannot change
without that document changing in the same commit, so it is the client's
stable reference.

**Error contract — two shapes, and the client parses both** (ADR-J D-3):

| Condition | Shape |
|---|---|
| any `/v1/**` failure | RFC 9457 `application/problem+json`: `type = https://errors.finance-a2ui/<code>`, `title`, `detail`, `instance`, `request_id` |
| an A2A method failure | a **JSON-RPC error object with HTTP 200** |
| a failure before the A2A envelope is parsed | an HTTP-level problem document, on the A2A surface |

So HTTP 200 is not success on the A2A surface. `detail` is safe to show a user
by backend contract (no stack trace, SQL or library text); a caught exception's
`toString()` is not.

`input_required` is a **normal terminal task state**, not an error (ADR-D D-3).

## 4. Architecture and layers

`client_flutter/` is a Dart pub workspace: `app/` (shipped) and `e2e_test/`
(out-of-process harness). `e2e_test/` depends on `app/`; `app/` never depends
on `e2e_test/`.

Inside `app/lib/src`, one way only — `view → bloc → repository → transport`:

| Layer | Owns | May import | Must not import |
|---|---|---|---|
| `main.dart` (composition root) | wiring: config, theme, the widget tree | everything below | — |
| `config/` | `AppConfig`; the only reader of `--dart-define` | Flutter, the SDK | anything under `features/` |
| `theme/` | `ColorScheme` + the `FinanceTokens` `ThemeExtension`; every colour | Flutter, the SDK | anything under `features/` |
| `features/<f>/view/` | widgets and pages | its own `bloc/`, `theme/`, `primitives.dart` | any `repository/`, any HTTP or connector type, another feature's `bloc/` |
| `features/<f>/bloc/` | state and transitions | its own `repository/`, `config/` | `package:flutter/material.dart`, any widget, any connector type |
| `features/<f>/repository/` | the only code that speaks to the backend or the genui connector | connector and HTTP packages, `config/` | any `view/`, any `bloc/` |

Rationale and the enforcement status of each row:
[`.claude/rules/client/architecture.md`](../../.claude/rules/client/architecture.md).
Drawn: [`docs/diagrams/11-client-architecture.md`](../../docs/diagrams/11-client-architecture.md).

**Navigation is `Navigator`, not `go_router`** (ADR-I D-1), so there are no URL
routes and no deep-link surface. The auth gate is a single component; feature
views never check auth themselves (D-3).

**The file budget is 220 lines** per `.dart` file under `*/lib/`, chosen for
Dart rather than inherited from Python. The reasoning is in the rule
(architecture §4) and is summarised in AC-2 below.

## 5. Security notes

Full rules: [`.claude/rules/client/security.md`](../../.claude/rules/client/security.md).
The control **mapping** (`client_flutter/docs/SECURITY.md`) is deferred to
spec `0002` — until it exists the rule file is the whole written posture, and
this spec claims no control it cannot point at.

- **Credential:** Firebase ID token only, `Authorization: Bearer`, with `X-A2A-Extensions` preserved beside it (ADR-B D-1, D-2). The refresh token never reaches our backend. The token lives only in the connector's mutable header map (D-9) and is never persisted — web has no secure storage, so nothing is persisted at all.
- **Refresh:** force-refresh + **one** retry on `auth/expired-token`; any other 401/403 signs the user out (D-7). No retry loop.
- **Secrets:** a `--dart-define` is compiled into the bundle in plaintext and is extractable from a web build. It may carry `BACKEND_BASE_URL` and public Firebase config; never an API key, never a token. The Gemini key lives in the backend and only there.
- **Committed material:** no `google-services.json`, `GoogleService-Info.plist`, keystore, provisioning profile or service-account JSON (D-10). Denied by repository permissions; `gitleaks` scans the full history in CI.
- **Logging:** no token, header, email or portfolio figure. `avoid_print` is enforced by `dart.analyze`; it stops `print`, not `debugPrint` or a careless `Logger` call, so the rule is wider than the lint.
- **Transport:** HTTPS outside loopback; no relaxed certificate validation, no ATS or cleartext exception without a spec entry.
- **Deep links:** none exist (ADR-I). The absence is the control; adding a scheme amends that ADR and brings input-validation rules with it.
- **Personal data:** portfolio payloads are personal financial data. They live for the session and are never written to disk.

## 6. Acceptance criteria

1. **AC-1** — `client_flutter/CLAUDE.md` answers, for the client, every question `backend/CLAUDE.md` answers for the backend: stack, run, verify, layout with import direction, enforced constraints, test rules, how to add a feature, security posture, do-not-touch. Every claim in it is true of the tree at merge, or carries `(planned)` / a named owning ticket.
2. **AC-2** — A Dart file-line budget is stated **with its reasoning in the rule**, not copied from Python. It is **220 lines**, justified by three verifiable facts: `analysis_options.yaml` enables `lines_longer_than_80_chars` and preserves trailing commas, so the formatter puts one widget argument per line; every file in the workspace carries a 14-line licence header; and of the twelve `.dart` files under `app/lib` at the time of writing the median is 65 lines, the second-largest 128, and exactly one — `features/landing/view/landing_page.dart`, at 247 — exceeds the budget, by doing three things at once.
3. **AC-3** — `.claude/rules/client/presentation.md` states the ADR-K constraint as five named bans — never format a number, never compute a figure, never derive a field, never interpret a template, never invent a view id — each with the rejected Dart beside the accepted Dart, and each with the concrete search a reviewer runs on a diff.
4. **AC-4** — All four client rules are registered in the root `CLAUDE.md` rules table with a `loads when` line, and each file's `paths:` front matter matches at least one real path in the tree.
5. **AC-5** — `docs/diagrams/11-client-architecture.md` is Mermaid-in-Markdown, names its question and its source of truth in the first line under the title, uses a `subgraph` per trust boundary and dashed edges for anything not built, and is registered in `docs/diagrams/README.md`.
6. **AC-6** — Every rule that is **not** enforced by a command says so in the rule, and every rule that **is** enforced names the `ship-gate.json` id and the command string. No rule claims a check that does not exist.
7. **AC-7** — No file owned by GGU-1 is created, edited or deleted: `.github/workflows/client-ci.yaml`, `.claude/ship-gate.json`, `.pre-commit-config.yaml`, `client_flutter/README.md`, `client_flutter/tool/**`, and everything under `client_flutter/app/{lib,test,android,ios}` and `app/pubspec.yaml`.
8. **AC-8** — `cd backend && make gate` is green on the branch.

## 7. Test plan

This PR ships documentation. The gate cannot check prose, so the checks below
are the ones a reviewer runs, and they are stated as commands rather than as
intentions.

| AC | How it is verified |
|---|---|
| AC-1 | Section-by-section diff against `backend/CLAUDE.md`'s headings; every factual claim traced to a file, an ADR or a `ship-gate.json` id |
| AC-2 | `find client_flutter/app/lib -name '*.dart' \| xargs wc -l \| sort -n` reproduces the median, the second-largest and the single file over 220 quoted in the rule |
| AC-3 | The five bans are present with both code forms and a search string each; `grep -c` over the rule confirms none was dropped |
| AC-4 | Each rule's `paths:` glob is expanded against the tree and matches ≥ 1 file; the four rows are present in the root `CLAUDE.md` table |
| AC-5 | The file renders on GitHub; node ids are stable words; `(planned)` or a dashed edge marks everything unbuilt |
| AC-6 | Every "enforced" claim resolves to an id in `.claude/ship-gate.json`; every other rule carries an explicit *review only* marker |
| AC-7 | `git diff --name-only origin/develop...HEAD` contains none of the listed paths |
| AC-8 | `cd backend && make gate` output pasted in the PR |

**Mutation checks required:** no — this PR changes no executable code. The
mutation checks this foundation *requires of future client PRs* are listed in
`.claude/rules/client/testing.md` §5, and the entry that matters most is
`X-A2A-Extensions`, whose omission degrades A2UI to a text agent **silently**.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Should the 220-line budget become a gate (`client.budget` + `tool/check_budget.sh`), or stay a review rule? | TL | becomes a gate once GGU-1's `ship-gate.json` changes have merged, copying the `check_tokens.sh` shape |
| OD-2 | Should the ≥ 80 %/file coverage bar be asserted in CI rather than uploaded as an artifact? | TL | assert it in `client-ci.yaml` after GGU-1 merges; leaving it unasserted indefinitely makes the number decorative |
| OD-3 | Should a `client.presentation` grep gate (`toStringAsFixed\|NumberFormat\|DateFormat\|double\.parse` under `lib/`) enforce ADR-K mechanically? | TL | yes — it is the only ADR-K ban that is cheap to check, and the verbatim-binding test is otherwise the sole defence |
| OD-4 | `bloc_test`, `mocktail` and `checks` are assumed by the generic Flutter rules and are not dependencies. Add them? | Timur (owns `app/pubspec.yaml` in GGU-1) | add `bloc_test` and `mocktail` with GGU-2's first real Bloc; until then, hand-written stream assertions |
| OD-5 | Does this app's Flutter web renderer force `unsafe-eval` into the CSP? | — (GGU-82 OD-3) | measured empirically in spec `0002`; if it does, the residual risk is recorded, not the header loosened |
| OD-6 | Rename `client_flutter/` → `frontend/`? | TL | no, not while GGU-1 is open — it would break both open PRs and the `paths:` filter of `client-ci.yaml` (GGU-82 OD-4) |

## 9. Rollout & observability

No runtime change, no feature flag, no migration: this PR adds documentation
and rules only, so there is nothing to roll back beyond a revert.

Two coupling notes for whoever merges next:

- The four rule rows added to the root `CLAUDE.md` table sit **inside the block that `/harness-init` regenerates**. That command must be taught to keep them, or the next run drops them silently. Flagged in the PR body.
- Three rules cite checks that do not exist yet (`client.tokens`, `client.config`, and the whole `client-ci.yaml`). They are cited by id with "lands with GGU-1" beside them, the way `ship-gate.json` already does. When PR #30 merges, those parentheticals come out — and `client_flutter/CLAUDE.md`'s "Verify" section stops needing its warning that a client-only PR can go green without compiling Dart.

Observability of the client itself (crash reporting, a Sentry DSN, a release
identifier in the bundle) is **not** addressed here and is not claimed
anywhere; it belongs to spec `0002` with the hosting decision.
