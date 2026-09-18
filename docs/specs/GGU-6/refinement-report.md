# Epic refinement report — GGU-6

- Run date: 2026-09-18 · Mode: **dry-run, then FULL RUN executed** · Integration branch SHA: **`410bb9d`** (local `main`)
- Operator: `/dev-epic-refinement` (harness) · Hardening engine: `jira-ticket-hardening` (**executed** — 7 rewritten, 1 commented)
- Epic: [GGU-6 "Epic 0 — Foundation"](https://somniosoftware.atlassian.net/browse/GGU-6) · project GGU (Google Gen UI) · **8 children** (GGU-46 created this run) · ~22h estimated after revisions
- Companion docs: **PR #1** — 9 ADRs + 3 contract specs + this report

> **Anchor caveat.** `git fetch origin` failed (SSH blocked by the sandbox). Every reality claim is
> anchored to the **local** `main` at `410bb9d` and may not reflect the remote. There is no
> `develop` branch; `main` is the integration branch. Re-run the reality pass with network access
> before acting on the file-level claims.

---

## Verdict

**Not bullet-proof. Do not start Wave 1.** The epic is well-written prose sitting on top of a
codebase it systematically mis-describes. Three classes of problem block it:

1. **A latent security defect that the tickets cannot catch.** GGU-3 can pass all six of its
   acceptance criteria and still ship a backend where any authenticated user can read and mutate
   any other user's session — and GGU-5 is the ticket that puts a portfolio behind it. See
   [Finding 1](#finding-1--session-isolation-is-unachievable-as-specified-p0).
2. **No governing records exist.** The repo has no `docs/` directory at all — no ADRs, no specs,
   no `DEV_HARNESS.md`. Nine architectural decisions are currently made in ticket prose, which is
   consumed and closed rather than retained. Three must be ratified before any code merges.
3. **Widespread contradictions between tickets and code.** 14 falsified claims, including two
   acceptance criteria that are literally unrunnable (iOS/Android targets do not exist) and one
   whole scope section describing a router that is not in the dependency tree.

Additionally, **GGU-4 is marked Done with unmet acceptance criteria** — the spike that GGU-2 and
GGU-3 both cite as their source of truth left no artifact.

What is genuinely good: the tickets are structurally consistent (Context / Scope / Do-Don't / AC /
Out of scope / Dependencies / Technical Design / Implementation Plan), the estimates look sane, and
each ticket's *Technical Design* section is markedly more accurate than its own header and
functional spec. GGU-45 is the only ticket with **zero** contradictions.

**All four escalations are now closed** (Navigator · live object · no allow-list · `max-instances=1`
— see [Escalations](#escalations-confusion-protocol)). **Remaining sequence before a full run:**
ratify ADR-C and ADR-A → then re-run `/dev-epic-refinement GGU-6` without `--dry-run`.

---

## Ticket map (before → after)

| Key | Type | Status | Reality verdict | Rewrite planned | Notes |
|---|---|---|---|---|---|
| [GGU-1](https://somniosoftware.atlassian.net/browse/GGU-1) | Task | To Do | **extend** | yes | Flutter workspace + web exist; **no `ios/`, no `android/`** — AC1 unrunnable. Owns a `ci.yaml` GGU-45 also owns. |
| [GGU-2](https://somniosoftware.atlassian.net/browse/GGU-2) | Task | To Do | **extend** | yes | `LoginBloc` is a fake accepting any credentials. No `firebase_auth`, no `go_router`. AC5 unimplementable under its own design. |
| [GGU-3](https://somniosoftware.atlassian.net/browse/GGU-3) | Task | To Do | **extend** | yes | Streaming server already works; endpoint table is fictional. **AC5 unachievable** — see Finding 1. |
| [GGU-4](https://somniosoftware.atlassian.net/browse/GGU-4) | Spike | **Done** | **extend** | comment only¹ | Wiring is real, but AC2 + AC3 unmet — no `docs/spike-findings.md`, no linked branch. **Falsely closed.** |
| [GGU-5](https://somniosoftware.atlassian.net/browse/GGU-5) | Task | To Do | **net-new** | yes | Zero hits for `portfolio\|holdings\|tax_lot` repo-wide. Circular dependency with GGU-3. |
| [GGU-12](https://somniosoftware.atlassian.net/browse/GGU-12) | Task | To Do | **net-new** | yes | Correctly scoped as ops-only. Cannot close inside Epic 0 — blocked on GGU-29 (Epic 4). |
| [GGU-45](https://somniosoftware.atlassian.net/browse/GGU-45) | Task | To Do | **net-new** | yes | **Every factual claim verified true.** Must land first. Zero links today. **Scope grows** — now also owns the `src/` packaging move (ADR-C), ~3h → ~5–6h. |

¹ GGU-4 is `Done`, so `jira-ticket-hardening` will comment rather than rewrite, per its status gate.

**Count reconciliation:** JQL `parent = GGU-6` returned 7; the epic's own child list agrees. No mismatch.

---

## Finding 1 — Session isolation is unachievable as specified (P0)

The single most important output of this run. Verified independently against the tree:

| Evidence | Fact |
|---|---|
| `backend_python/agent.py:70` | `self._user_id = "remote_agent"` — one **constant** ADK user id for every caller |
| `backend_python/agent.py:218-229` | Sessions are keyed by `(app_name, user_id, session_id)`; two of the three are constants, so **`session_id` alone** is the key |
| `backend_python/agent_executor.py:174` | `self._agent.stream(query, task.context_id, ...)` — the ADK `session_id` **is** the A2A `context_id` |
| `genui_a2a-0.10.1/.../a2ui_agent_connector.dart:40-41,150-152` | `contextId` is **supplied by the client** |

Any authenticated caller who presents another user's `contextId` reads and mutates that session.
GGU-3's AC2 (token verified) and AC5 (sessions isolated) are independent — **AC2 can pass while AC5
is false**, and AC5 as scoped ("two session_ids don't share state") tests the wrong property.

**Compounding defect — there is not one session store, there are three.** `agent.py:143-150`
constructs a **fresh `InMemorySessionService()` on every `_build_runner` call**, and it is called
three times (text runner, v0.8, v0.9). A client that renegotiates the extension version lands in a
different store with a separately seeded portfolio. Both GGU-3 (plan item 3) and GGU-5 (plan item
5) describe seeding "the `session_state` dict" as if it were singular. It is not.

**Required:** ratify ADR-A, and add an AC to GGU-3 — *"a session opened under uid A cannot be read
or resumed by uid B, even when B presents A's contextId"* — proven by test.

---

## Link graph

### Existing links (15 — none proposed for deletion)

```
GGU-1 ──blocks──▶ GGU-2          GGU-3 ──blocks──▶ GGU-5
GGU-1 ──blocks──▶ GGU-13 *       GGU-3 ──blocks──▶ GGU-13,14,15 *
GGU-2 ──blocks──▶ GGU-12         GGU-5 ──blocks──▶ GGU-12
GGU-2 ──relates─▶ GGU-3          GGU-5 ──blocks──▶ GGU-14 *
GGU-4   (none)                   GGU-45  (none)
```
`*` = outside this epic.

### LINK DELTA — 8 additions, 0 deletions (**not applied; dry run**)

| From | Link type | To | Why |
|---|---|---|---|
| GGU-45 | blocks | GGU-1 | Both plan to create `.github/workflows/ci.yaml`; GGU-45 owns it |
| GGU-45 | blocks | GGU-3 | GGU-3 plans 4 files under `backend_python/tests/` — neither the dir nor pytest config exists |
| GGU-45 | blocks | GGU-5 | GGU-5 plans 4 more test files there; both also duplicate `py.typed` and `[tool.ruff]` |
| GGU-2 | blocks | GGU-3 | GGU-3's own header says "Depends on GGU-2 (token contract)"; only `relates` is recorded |
| GGU-3 | blocks | GGU-12 | GGU-12's header lists GGU-3, and its AC2 needs a live session on prod |
| GGU-4 | blocks | GGU-3 | GGU-3's AC3 reads "verified in the spike (GGU-4)" |
| GGU-4 | relates to | GGU-1 | Spike pins the package versions and the web-render caveat driving GGU-1's pubspec + CI |
| GGU-4 | relates to | GGU-2 | Spike's transport choice determines where the Bearer header attaches |

GGU-45 → GGU-2 is covered transitively via GGU-45 → GGU-1 → GGU-2; no direct link needed.

### Suspected-wrong existing links (flagged for TL — **never deleted by this run**)

1. **`GGU-3 blocks GGU-5` — too strong, and half-backwards.** GGU-5's PR1 (`portfolio.py` models,
   `seed_portfolio`, invariants, tax-lot term tests — ~4 of its 5h) is a standalone pydantic module
   with no dependency on GGU-3. The link's stated rationale is that GGU-3 *creates* the session
   seam, but that seam is already in the tree at `agent.py:204`. Meanwhile GGU-3's plan item 3 reads
   "seed GGU-5's `Portfolio` into `session_state`" — which needs GGU-5's type. **A literal circular
   dependency.** *Recommendation: don't reverse it — split GGU-5 into model (Wave 1) vs wiring
   (Wave 3) and scope the block to the wiring half. Taken at face value this link serializes ~4h.*
2. **`GGU-2 relates to GGU-3` — under-specified, not wrong.** It records the pairing but loses the
   directionality GGU-3's own header asserts. The delta adds `blocks` *alongside* it rather than
   replacing it, because the dependency genuinely runs both ways (GGU-2 also needs GGU-3 to add
   `firebase-admin`).
3. **`GGU-2 blocks GGU-12` — correct but incomplete as the only path.** GGU-12's real gate also
   includes GGU-29 (prod `authorizedDomains`, currently `["localhost"]` in `firebase.json:17`),
   which is outside this epic and expressed by no link.

---

## Gaps — planned actions (dry run: nothing created)

### Would create: 2 tickets

| Intended summary | Type | Why |
|---|---|---|
| **Create iOS and Android platform targets for the Flutter app** | Task | `client_flutter/app/` has only `macos/` and `web/`; `.metadata` registers only `root` + `macos`. The epic promises "(iOS, Android, Web)" and GGU-1 AC1 asserts all three boot. `flutter create --platforms=ios,android`, bundle ids, and the Firebase mobile config files are owned by **no ticket**. GGU-1's estimate does not reflect this. |
| ~~Restructure `backend_python/` to `src/` + layered packages~~ | — | **Withdrawn (TL): folded into GGU-45.** See ADR-C below. |

Idempotency: both would be JQL-searched against the epic's children before creation, and the new
key re-fetched to confirm before being added to `TICKET_MAP`.

### Would author (companion-docs PR off `main`, separate worktree — *not* the user's checkout)

- `docs/specs/GGU-3/api-contract.md` — **highest priority.** GGU-3's in-ticket endpoint table
  (`POST /v1/session`, `GET /healthz`) describes a service that does not exist and will not be
  built; the real surface is A2A JSON-RPC `message/stream` at `/`. A developer coding to the ticket
  would build the wrong thing. Five sections (`/healthz`, agent card, `message/stream`,
  `tasks/cancel`, `/static/*`) plus a 10-row RFC 9457 error table — currently the client can only
  see an opaque `A2AException.http`, so it cannot distinguish *expired* from *revoked* from
  *not-allowed*, which is precisely what GGU-2's "refresh + single retry on 401" needs.
- `docs/specs/GGU-2/api-contract.md` — thin client-side half: exact header set (including the
  `X-A2A-Extensions` re-supply), token refresh seam, sign-out semantics, the negative contract
  (refresh token never leaves the client), and the `provision_user.py` interface.
- `docs/specs/GGU-5/domain-contract.md` — a *module* contract, not an api-contract. Epic 1's four
  tool tickets cannot start without the read-surface signatures, the typed session-state accessor,
  the exact-equality invariants, and the price-history window.

Tickets would cite these only once merged, carrying a **"pending contract PR"** Open Decision until then.

### ADR proposals — 9, for TL ratification (proposals only; nothing committed to `docs/adr/`)

| ADR | Subject | Priority |
|---|---|---|
| **ADR-C** | Backend module layout — **DECIDED: move to `src/` inside GGU-45** ✅ | **P0 — is GGU-45** |
| **ADR-I** | Client routing and auth gating — **DECIDED: Navigator** ✅ | **P0 — before GGU-1** |
| **ADR-A** | Session identity, ownership and isolation | **P0 — before GGU-3** |
| ADR-B | Auth credential contract (Firebase ID token, allow-list, refresh policy) | P1 — before GGU-2/GGU-3 code |
| ADR-D | A2UI streaming transport (ratifies what GGU-4 proved) | P1 |
| ADR-E | Money representation and rounding (`Decimal`) | P1 — before GGU-5 |
| ADR-F | In-memory-only persistence and session lifetime | P1 — before GGU-5 |
| ADR-G | Secret handling in a public repository | P2 — before first deploy |
| ADR-H | CI and ship-gate contract | P2 — ratifies GGU-45 |

Why these three are P0: **ADR-C** must precede GGU-45 because GGU-45 bakes the layout into
`[tool.pytest]`/pyright/coverage config — deciding after means redoing GGU-45. **ADR-I** blocks
GGU-1, which blocks GGU-2 and all of Epic 1; it is the cheapest decision here and the most
expensive to reverse. **ADR-A** blocks GGU-3 *and* GGU-5, whose ACs are false without it.

### Wrong-project work

**None found.** All 7 tickets belong in GGU. Cross-epic links to GGU-13/14/15 (Epic 1) and the
GGU-29 dependency (Epic 4) are legitimate and stay as-is.

---

## Duplicate-capability matrix (12 collisions — resolve before any ticket starts)

| Path / capability | Claimed by | Owner | Others do |
|---|---|---|---|
| `.github/workflows/ci.yaml` | GGU-1 #10, GGU-45 #5 | **GGU-45** | GGU-1 contributes 2 grep steps |
| `backend_python/pyproject.toml` `[tool.*]` + dev group | GGU-3 #2, GGU-5 #6, GGU-45 #1 | **GGU-45** | runtime deps only |
| `backend_python/py.typed` | GGU-3 #7, GGU-5 #7, GGU-45 #2 | **GGU-45** | — |
| `backend_python/tests/test_session_isolation.py` | GGU-3 #11, GGU-5 #11 | **split by concern** | GGU-3 → `test_session_identity.py`; GGU-5 → `test_portfolio_isolation.py` |
| `agent.py` `session_state` (same 4 lines) | GGU-3 #3, GGU-5 #5 | **GGU-5** fills the slot | GGU-3 reserves the mechanism |
| `landing_repository.dart` constructor | GGU-1 #7, GGU-2 #7 | **sequence, don't split** | GGU-1 lands `AppConfig`, then GGU-2 swaps to the `client:` form |
| `backend_python/README.md` | GGU-2 #11, GGU-3 #13, GGU-5 #12 | **GGU-3** owns structure | others append named sections |
| Provisioning runbook (two paths) | GGU-2 #11, GGU-12 #5 | **GGU-2** creates; pick one path | `docs/provisioning-runbook.md` once `docs/` is real |
| `firebase-admin` dependency | GGU-2 #8 needs, GGU-3 #2 adds | **GGU-3** adds | ⚠️ undeclared edge: GGU-2's script can't land before GGU-3 |
| Prod origin / authorized domain | GGU-2, GGU-3, GGU-12 | all defer to **GGU-29** (out of epic) | make it an explicit link on GGU-12 |
| `client_flutter/app/test/config_test.dart` | GGU-1 #9, GGU-2 implicit | **GGU-1** | GGU-2 appends cases |
| **Mobile builds in CI — an AC conflict** | GGU-1 AC6 requires iOS+Android+Web artifacts; GGU-45 scopes mobile to GGU-27 | **GGU-45** owns CI | **GGU-1 AC6 must be rewritten to web-only** or GGU-1 can never be marked Done |

---

## Contradictions — 14 ticket claims falsified at `410bb9d`

| Ticket | Claim | Reality |
|---|---|---|
| GGU-1/2/3/5 | Repo is `app/` + `backend/` | `client_flutter/app/` and `backend_python/`. Only GGU-45 gets this right. Each ticket's *Technical Design* self-corrects; the headers do not. |
| GGU-1 | AC1: boots on **iOS and Android** | No `ios/`, no `android/` dir. `.metadata:18-20` registers only `macos`. **Unrunnable.** |
| GGU-1 | "What exists today" enumeration | Omits that `macos/` exists and `ios/`+`android/` do not — the one fact that changes the estimate |
| GGU-2 | Scope 4 + AC5: **`go_router` redirect**, routes `/login`, `/`, `/surface` | No `go_router` dependency. Routing is `Navigator.pushReplacement` (`login_page.dart:55`). **No named route table exists at all.** |
| GGU-2 | AC1: logs in on web, iOS, Android | Same missing-platform problem |
| GGU-2 | Header: "Blocks GGU-Provision-Google-account" | Placeholder key; the real key is GGU-12 (the Jira link itself is correct) |
| GGU-3 | Endpoint table: `POST /v1/session`, `GET /healthz` | Neither exists. Transport is A2A JSON-RPC at `/`, card at `/.well-known/agent-card.json` |
| GGU-3 | Header: "**Blocks** GGU-4 (spike wiring)" | **Inverted.** GGU-4 is Done, GGU-3 is To Do — the spike proved GGU-3's transport, not the reverse |
| GGU-3 | AC3: "verified in the spike (GGU-4)" | The spike produced no artifact to verify against |
| GGU-4 | AC2: findings in `docs/spike-findings.md` | `docs/` does not exist anywhere in the repo |
| GGU-4 | AC3: pointer to the spike branch | Only `main`/`origin/main` reachable; no spike commit in the 8-commit history |
| GGU-12 | Scope 1: `backend/scripts/provision_user.py` | Wrong path *and* nonexistent — `backend_python/scripts/` doesn't exist either |
| GGU-3 (implied) | Cloud Run deploy works | `__main__.py:51` `base_url = f"http://{host}:{port}"` + `Dockerfile:13` `--host 0.0.0.0` → the agent card will advertise **`http://0.0.0.0:8080`** and every coin logo URL will point at `0.0.0.0`. Needs a `PUBLIC_BASE_URL` separate from the bind address. |
| GGU-45 | — | **No contradictions found.** All claims verified true. |

### Coverage gaps — epic scope owned by no ticket

1. **iOS/Android platform targets** (see planned ticket above).
2. **`macos/` is in the tree and unowned** — fully populated `Runner.xcodeproj`; no ticket says keep, ship, or delete. Silently widens the platform matrix and the CI bill.
3. **`client_flutter/e2e_test` is dead at HEAD** — `test_infra/restaurant_finder.dart:62` spawns the backend from `'../../server'`, which does not exist. Both e2e tests are broken independent of the restaurant/crypto mismatch. Orphaned between GGU-1 and GGU-3.
4. **`.vscode/launch.json` points at `flutter_client/app` and `server`** — neither directory exists. No ticket touches it.
5. **De-restaurant cleanup has no acceptance criterion.** `name: restaurant_finder_client`, both READMEs, and `session_test.dart:33` ("can find restaurants and book a reservation"). GGU-1 lists the rename in its plan but **no AC gates it**, so it can ship half-done.
6. **Price-series contract** — GGU-5 needs a window the attribution tool (GGU-36, Epic 1) defines; nobody in Epic 0 owns it.
7. **`tasks/cancel` always errors** (`agent_executor.py:214-217` raises `UnsupportedOperationError`) while the client calls it on every cancellation. In no ticket's scope.

---

## Test strategy summary (shapes the Tests / UAT / Loop sections)

**The current test signal is actively misleading.** `app/test/widget_test.dart:26` pumps the app and
asserts nothing — that is the entire Flutter suite, so `flutter test` is green today on a broken
app. Any ticket reporting "tests green" before GGU-1 replaces that file is reporting nothing.

**Prerequisite refactor, or GGU-3 is untestable:** `__main__.py:41-84` builds the app *and* calls
`uvicorn.run()` inside one `try/except Exception: exit(1)`. **There is no app factory**, so no
integration test can construct the Starlette app — GGU-3's AC2/AC3/AC6 are untestable until
`build_app(...)` is extracted. Relatedly, `StaticFiles(directory="images")` is CWD-relative, so any
pytest that builds the app fails unless cwd is `backend_python/`. Both belong in GGU-45 or GGU-3 as
**scope items, not nice-to-haves**.

**Proposed ship gate** (GGU-45's payload; `.claude/ship-gate.json` `required` is `[]` today):

| Stack | Commands |
|---|---|
| Python (`backend_python/`) | `uv run ruff check .` · `ruff format --check .` · `basedpyright` · `pytest --cov --cov-branch` |
| Flutter (`client_flutter/`) | `dart format --set-exit-if-changed .` · `dart analyze --fatal-infos` · `flutter test` · `flutter build web` |

Coverage `fail_under` starts at **50–60**, ratcheting to 80 after GGU-5 — starting at the rule's 80
blocks PR1 on a repo with zero tests. `e2e_test/` is **excluded** from the PR gate (needs a real
`GEMINI_API_KEY`, a live backend, 10-minute timeouts) and gets an opt-in workflow.

**E2E:** extend the existing Dart `e2e_test` package rather than replacing it — it drives the real
bloc + repository and shares the app's type system, so a surface-contract break is a compile error.
Flutter web renders to canvas, so a DOM-selector tool is nearly blind. Add a **thin 4-case
Playwright suite** only for what Dart structurally cannot see (auth persistence across reload
including Incognito, deep-link redirect, browser back/forward, canvas-paints-at-all). Maestro earns
its place in exactly two spots: GGU-2's kill-and-relaunch persistence, and GGU-12's mobile reviewer
walkthrough.

**Where tests would lie:**
- A passing `test_auth.py` **with the middleware commented out** is the default failure mode here —
  require a demonstrated mutation before accepting the auth work.
- Mocked Firebase proves the error-code mapping, not that Firebase rejects a bad password. At least
  one path must run against the Firebase Auth emulator.
- CORS **cannot** be tested as "blocked" — Starlette omits the header, it does not return 403.
  Writing the AC as "403" produces an unpassable test; restate as "header absent".
- `AppConfig` reading `String.fromEnvironment` inline is **const-folded at compile time** and
  silently always passes. Needs an `AppConfig.fromMap()` testable core.
- `agent.py` already retries once on schema-validation failure, so a "surface renders" e2e can pass
  on attempt 2 while attempt 1 was garbage — the retry masks prompt regressions.
- **Nothing tests that a Cloud Run cold start re-seeds a coherent portfolio** — the single most
  likely reviewer-facing failure.

---

## Auto-decisions (autonomous mode)

| # | Decision | Rationale | Would be recorded in |
|---|---|---|---|
| 1 | Anchor reality claims to **local `main` @ 410bb9d**, not `origin/develop` | `git fetch` blocked by sandbox SSH; no `develop` branch exists on origin. Stopping would have produced zero value from an otherwise-complete run. | Report header + every ticket's Context |
| 2 | Treat **`main`** as the integration branch | Only branch on origin. The skill's default (`origin/develop`) does not exist here. | Report |
| 3 | Substitute the built-in **`Plan`** agent for ruflo **`planner`** in Step 5 | `planner` is not a registered subagent type in this session; ruflo exposes MCP tools, not an agent type. Capability is equivalent for dependency decomposition. | Report |
| 4 | Treat **`.claude/rules/**`** as the de-facto governing records | `docs/adr/` does not exist, so the ADR-citation discipline had nothing to cite. The rules files are the only durable, repo-committed normative documents. | ARCH_VERDICTS, ADR proposals |
| 5 | Keep issue type **Task** for gap tickets (not Story) | GGU offers Story/Task/Bug/Spike, but `CLAUDE.md` documents no Jira convention and 6 of 7 existing children are Task. Following the established pattern beats imposing one. | Report |
| 6 | Do **not** propose deleting any existing link | Skill hard rule: links are idempotent, additions only. The 3 suspected-wrong links are listed for the TL instead. | Link graph |
| 7 | Corrected the architecture review's claim that **no `.dockerignore` exists** | Verified directly: `backend_python/.dockerignore` exists and already excludes `.env`, `.venv`, `.git`, `.claude`. ADR-G D-2 is amended accordingly. | This report |
| 8 | Recorded GGU-4 as **extend**, not `exists-already` | The wiring is genuinely in the tree, but two of three ACs are unmet. Marking it `exists-already` would have hidden the falsely-closed status. | Ticket map |

---

## Escalations (Confusion Protocol)

Four decisions were raised. **All four are resolved (TL, 2026-09-18).** No blocking ambiguity
remains; a full run may proceed.

### 1. Routing — **RESOLVED 2026-09-18 (TL): Navigator.** ✅

`go_router` is **not** adopted. The client keeps imperative navigation with a single auth-gate
component. Consequences that the hardening rewrite must apply:

- **GGU-2 AC5 is deleted** — deep-link to `/surface` → redirect → post-login return is
  unimplementable without URL routes. There is no `/surface` URL.
- **GGU-1 AC2 is rewritten** to drop browser back/forward.
- **ADR-I D-1 = Navigator**, and the deviation from `.claude/rules/flutter/code-patterns.md`
  ("configure `redirect` for authentication flows") is recorded there rather than left implicit.
- **ADR-I D-3 stands:** the auth gate is a single component; feature views MUST NOT perform their
  own auth checks.
- Test-plan consequence: Playwright cases 2 (deep-link redirect) and 3 (back/forward) are dropped;
  cases 1 (auth persistence across reload, incl. Incognito) and 4 (canvas paints) remain. The
  `client_flutter/app/test/routing/` test directory is not created.

### 2. Session state — **RESOLVED 2026-09-18 (TL): live object.** ✅

`state["portfolio"]` holds the live `Portfolio`. **ADR-F D-3 is amended** from "MUST remain
JSON-serializable" to: *the portfolio is stored as a live object; all access goes through
`get_portfolio(tool_context) -> Portfolio` and `save_portfolio(tool_context, portfolio)`.*

The accessor pair is **load-bearing, not stylistic** — it is what keeps this reversible. Epic 1's
four tool tickets (GGU-36–39) MUST NOT read `state["portfolio"]` directly; with a single choke
point, adopting a persistent session service later is a two-function change instead of a rewrite.
`save_portfolio` also gives one place to write the ADK state delta, rather than relying on in-place
mutation working by accident. This constraint belongs in `docs/specs/GGU-5/domain-contract.md` and
in GGU-5's Do/Don't.

Background retained for reviewers:



ADK session state is a plain dict. `InMemorySessionService` holds live Python objects;
`DatabaseSessionService` / `VertexAiSessionService` persist state and therefore require
JSON-serializable values. Storing a live `Portfolio` forecloses that swap. Storing a dump preserves
it but costs a `model_validate` per tool call and needs an explicit `Decimal` codec (`Decimal`
round-trips as a **string**; parsing it back via `float` silently reintroduces the drift ADR-E
exists to prevent).

Second, subtler cost of the live object: ADK persists state through **event deltas**, not by
observing in-place mutation. A live object appears to mutate correctly only because it is the same
object in memory — an implementation detail, not a contract. `agent.py:230-231` already does this.

A typed accessor is required regardless of which way this went — under pyright,
`state.get("portfolio")` returns `Any` and propagates `Unknown` into every tool
(`typing.md` R6/R8).

### 3. Access control — **PARTIALLY RESOLVED 2026-09-18 (TL).**

**Resolved:** the Gemini key lives in **Google Cloud Secret Manager**, not in the repo. Verified
clean — `backend_python/.env` is untracked, ignored by `backend_python/.gitignore:2`, and appears in
**no commit in the repo's 8-commit history**. Nothing needs scrubbing before the repo goes public.
ADR-G D-1/D-2 are satisfied; `.dockerignore` already excludes `.env`, `.venv`, `.git`, `.claude`.

**Resolved — no uid allow-list (TL).** Email/password is the **only** auth provider, and no other
method is planned. Access control is therefore: (a) email/password is the sole enabled provider,
and (b) accounts are provisioned by us, never self-signup. **ADR-B D-5 is amended** from "allow-list
required" to *"no allow-list; email/password provisioned-only is the control."*

To bank the safety at zero code cost, **ADR-B gains D-5a: "email/password is the only enabled
Firebase Auth provider."** Recording it as a ruling means enabling a second provider becomes a
deliberate ADR amendment rather than a silent console toggle — which is the only way the control
could quietly disappear.

### 5. Backend module layout (ADR-C) — **RESOLVED 2026-09-18 (TL): done inside GGU-45.** ✅

The flat-for-Epic-0 recommendation is **superseded**. `backend_python/` moves to a `src/` package as
part of GGU-45, not in a later ticket. Rationale: GGU-45 lands first, so restructuring there is far
cheaper than after GGU-3 and GGU-5 write new modules into a flat tree, and GGU-45 configures
ruff / pytest / pyright / coverage for the **final** layout once instead of twice.

**Scope boundary — packaging move only, not layering.** ADR-C D-5's full
`api/application/domain/infrastructure` split with `Protocol` boundaries is **deferred**: you cannot
layer a domain that does not exist yet, and GGU-5 has not been written. GGU-45 delivers:

- `src/a2ui_crypto_market/` with `__init__.py` + `__all__`, real package imports replacing the bare
  top-level `from tools import …` / `from agent import …`
- `pyproject.toml` `packages = ["src/a2ui_crypto_market"]` (replacing `packages = ["."]`, which
  packages the working directory — a latent build hazard, ADR-C D-7)
- Dockerfile entry point updated off `uv run .`
- tool config written against the new layout

Layering is revisited **after GGU-5 lands**, before Epic 1's tool tickets (GGU-36–39).

**Accepted cost:** GGU-45 grows from ~3h to **~5–6h**, and it is Wave 0 gating every other ticket.
The critical path lengthens by ~2–3h. Taken knowingly — the alternative is paying more later.
**ADR-C D-6 still applies:** new backend modules MUST NOT import "upward", so `portfolio.py` (GGU-5)
must not import from `agent.py`, `agent_executor.py` or `__main__.py`.

### 4. Cloud Run scaling — **RESOLVED 2026-09-18 (TL): `max-instances=1`.** ✅

**ADR-F D-4 is ratified** as written: `min-instances=1, max-instances=1` for the review window,
because in-memory session state and autoscaling are incompatible. This must be stated in GGU-3's
deploy configuration and its Technical Design — no ticket currently says it, and the failure mode
(a reviewer's follow-up turn routed to an instance with no session) is silent.

Consequence for GGU-12, already noted in ADR-F D-5: the reviewer's portfolio still resets on a cold
start. The mitigation is that the seed is deterministic and curated (GGU-5 AC6), so a reset is
always *coherent* — and GGU-12 AC2 must **verify** this rather than assume it.

---

## Hardening brief (for the full run — `jira-ticket-hardening` was **not** invoked)

When re-run without `--dry-run`, hardening receives:

- **`TICKET_MAP` as the authoritative frozen tree** — exactly `GGU-1, GGU-2, GGU-3, GGU-4, GGU-5,
  GGU-12, GGU-45`. It skips its own enumeration.
- **Autonomous mode**, with the frozen `REALITY_REPORT`, `ARCH_VERDICTS`, `TEST_PLAN`, and the
  priority order from `CHAIN_PLAN`. It skips its own probes for these inputs.
- **Status gate:** GGU-4 is `Done` → **comment only**, never rewritten. The other six are `To Do` →
  rewritten in place.
- **Citation table:** empty. There are no ADRs to cite. Every ticket carries a "pending ADR" Open
  Decision naming its blocking ADR (GGU-1 → ADR-I; GGU-3 → ADR-A, ADR-B, ADR-D; GGU-5 → ADR-A,
  ADR-E, ADR-F; GGU-45 → ADR-C, ADR-H).

**Template delta to close — none of the 7 tickets currently has any of these sections:**

| Section | Present today |
|---|---|
| Story | GGU-1 only |
| Tests | **0 / 7** |
| UAT | **0 / 7** |
| Loop-Engineering Strategy | **0 / 7** |
| Open decisions (owner + default-if-unresolved) | **0 / 7** |

Everything else (Context, Scope, Do/Don't, AC, Out of scope, Dependencies, Technical Design,
Implementation Plan) is present and largely sound — GGU-12 additionally lacks "How to verify".

**Per-ticket rewrite must also fix:** the `app/`→`client_flutter/app/` and `backend/`→`backend_python/`
path drift in GGU-1/2/3/5 headers; GGU-2's `GGU-Provision-Google-account` placeholder → GGU-12;
GGU-3's fictional endpoint table → the real A2A surface; GGU-3's inverted "Blocks GGU-4"; GGU-1 AC6
→ web-only; GGU-1 AC1 and GGU-2 AC1 → gated on the new iOS/Android ticket.

---

## Proposed: split GGU-3 (pending TL confirmation)

GGU-3 is the largest ticket (6h) and sits mid-critical-path. **A backend/client split is not the
productive cut** — of its 13 implementation rows, exactly one touches the client (row 12,
`client_flutter/e2e_test/test/session_test.dart`), and that file is already contested with GGU-1
row 11 (the `restaurant_finder.dart` rename + dead `'../../server'` path fix). A client-side GGU-3
would be a one-file ticket fighting GGU-1 for that file.

The seam runs along a different axis — the one GGU-3's own "Suggested PR sequence" already names:

| Proposed | Scope | Depends on | Wave | Est |
|---|---|---|---|---|
| **GGU-3a** Service hardening + Cloud Run deploy | `/healthz`, `PUBLIC_BASE_URL` fix (§Contradictions), `settings.py` fail-fast, CORS, Dockerfile, deploy config | GGU-45 only | **1** | ~2.5h |
| **GGU-3b** Firebase auth middleware | token verification, 401 table, uid→session binding (ADR-A), `test_auth.py`, the e2e auth case | GGU-2 token contract | 2 | ~2.5h |
| ~~GGU-3c~~ session/portfolio seam | **fold into GGU-5** — do not create | — | 3 | ~1h |

**Why GGU-3c folds into GGU-5 rather than becoming a ticket.** This is where the epic's one genuine
circular dependency lives: GGU-3 row 3 says "seed GGU-5's `Portfolio` into `session_state`", GGU-5
row 5 says "add a `portfolio` slot beside `base_url`", and both edit the same four lines at
`agent.py:204`. Merging the work into GGU-5 dissolves the cycle outright and is what allows the
suspected-wrong `GGU-3 blocks GGU-5` link to be re-scoped to the wiring half only.

**Schedule effect:** GGU-3a moves **off the critical path into Wave 1**, parallel with GGU-1 and
GGU-5's model PR. This is the single largest scheduling win available in the epic, and it partly
offsets the ~2–3h that ADR-C adds to GGU-45.

**Link delta if the split is confirmed** (replaces the GGU-3 rows above): `GGU-45 blocks GGU-3a` ·
`GGU-45 blocks GGU-3b` · `GGU-2 blocks GGU-3b` · `GGU-4 blocks GGU-3a` · `GGU-3a blocks GGU-3b` ·
`GGU-3a blocks GGU-12` · `GGU-3b blocks GGU-12`. Cross-epic links currently on GGU-3
(→ GGU-13/14/15) attach to **GGU-3b**.

---

## Delivery plan

> Waves below reflect the **pre-split** shape. Confirm the GGU-3 split above and Wave 1 gains
> GGU-3a while Wave 2 narrows to GGU-2 ∥ GGU-3b.

**Critical path (16.5h of the 19.5h estimate):**

```
GGU-45 (3h) → GGU-1 (3h) → GGU-2 (3h) → GGU-3 auth (~3h of 6h) → GGU-5 wiring (~1h of 5h) → GGU-12 (0.5h)
```

| Wave | Tickets | Notes |
|---|---|---|
| 0 | **GGU-45** | Serial. Collapses three duplicate tooling efforts into one and gates every later PR. |
| 0b | **GGU-4** closeout (~0.5h) | Parallel, non-blocking. Write `docs/spike-findings.md`. |
| 1 | **GGU-1** ∥ **GGU-3 PR1** ∥ **GGU-5 PR1** | Disjoint files, different stacks. |
| 2 | **GGU-2** ∥ **GGU-3 PR2** (auth) | Only parallel if the token contract (ADR-B) is fixed in Wave 0. |
| 3 | **GGU-5 PR2** (session wiring) | Serial — same lines of `agent.py` as GGU-3. |
| 4 | **GGU-12** | Four-way fan-in; **cannot close without GGU-29** (Epic 4). |

Three developers ≈ **11.5h wall clock** vs 19.5h of effort. Under the *current* link graph (GGU-3
blocking all of GGU-5) the path swells to ~19h — re-scoping that one link is the highest-leverage
schedule change available.

**Biggest scheduling risk:** GGU-3 is the largest ticket, sits mid-path, and depends on four
external prerequisites **no ticket in this epic owns** — a GCP project with billing, Cloud Run,
Secret Manager, and a Firebase Admin service account. `.firebaserc` naming `finance-a2ui` does not
prove the project exists and is enabled. The delay would surface late, at GGU-3 PR1.

**Epic-closure blocker:** GGU-12 cannot complete inside Epic 0. Its AC2 demands prod-web
verification, but `firebase.json:17` has `authorizedDomains: ["localhost"]` — web login fails on any
real domain until GGU-29 lands. Either pull that change into GGU-2/GGU-3, or accept that Epic 0
closes on an Epic 4 dependency and link GGU-12 → GGU-29 so it is visible.

---

## Evidence

- **Reality probes** — built-in `Plan` agent, 30 tool calls, all 7 descriptions read and every claim
  checked against the tree. Headline claims re-verified independently by the orchestrator:
  `client_flutter/app/` platform dirs, `.metadata:18-20`, `login_bloc.dart:13`, the
  `portfolio|holdings|tax_lot` grep, `go_router`/`firebase_*` absence, `app/pubspec.yaml:15`,
  `agent.py:70,143-150,204,218-231`, `agent_executor.py:174`, `__main__.py:51`, `.dockerignore`.
- **Architecture** — `system-architect`, 29 tool calls. Cited **zero ADRs, because none exist**;
  used `.claude/rules/**` as the standing rulings. One claim corrected by the orchestrator
  (`.dockerignore`, auto-decision #7).
- **Test planning** — `tester`, 31 tool calls. Produced the ship-gate command set, the duplicate-file
  matrix, and 9 false-confidence risks.
- **Chain planning** — built-in `Plan` agent (substituting for ruflo `planner`, auto-decision #3),
  12 tool calls.
- **FE evidence (gstack `browse`)** — **not gathered.** No develop/sandbox environment is deployed
  (GGU-3 AC1 is precisely the ticket to deploy one), so there was no running FE to inspect. No
  secrets were read or echoed at any point in this run.
- **Hardening verify sweep** — **N/A**, dry run. No Jira writes, no snapshot directory, no
  rollback baseline.

---

## What a full run would do

1. ~~Close the escalations~~ — **all four closed.** Ratify ADR-C (backend layout) and ADR-A
   (session identity); ADR-I, ADR-B D-5/D-5a and ADR-F D-3/D-4 are decided above.
2. Create the iOS/Android gap ticket. The backend-restructure ticket is **withdrawn** (folded into
   GGU-45). If the GGU-3 split is confirmed, create **GGU-3a** and **GGU-3b** and re-point GGU-3's
   cross-epic links at GGU-3b.
3. Open the companion-docs PR with the 3 contract specs.
4. Apply the link additions — 8 pre-split, or the revised set if GGU-3 splits.
5. Drive `jira-ticket-hardening` over the frozen key set — rewriting the To-Do tickets, commenting
   on GGU-4 (Done).
6. Re-fetch every ticket and verify against hardening's manifest.

---

# RUN OUTCOME — full run executed 2026-09-18

The dry-run sections above are preserved as the pre-execution record. This section is what actually happened.

## Verify manifest (exhaustive — every ticket re-fetched, not a sample)

| Key | Action | Status at edit | 12 template sections | Tables | Size before → after |
|---|---|---|---|---|---|
| GGU-1 | rewritten (pilot) | To Do | ✅ all | ✅ 3 | 13,981 → 14,491 |
| GGU-2 | rewritten | To Do | ✅ all | ✅ 3 | 12,248 → 20,395 |
| GGU-3 | rewritten | To Do | ✅ all | ✅ 5 | 14,399 → 19,543 |
| GGU-4 | **comment only** | **Done** | n/a — gate held | ✅ 1 | 4,300 → **4,300 (byte-identical)** |
| GGU-5 | rewritten | To Do | ✅ all | ✅ 5 | 14,167 → 23,973 |
| GGU-12 | rewritten | To Do | ✅ all | ✅ 3 | 6,842 → 13,786 |
| GGU-45 | rewritten (pilot) | To Do | ✅ all | ✅ 3 | 10,158 → 14,187 |
| GGU-46 | rewritten (created this run) | To Do | ✅ all | ✅ 4 | 5,648 seed → 21,688 |

- **Snapshot directory (rollback baseline):** `scratchpad/snapshots/GGU-6-2026-09-18/` — all 8 captured before any edit.
- **Zero phantom ADR refs.** All citations resolve to the 9 lettered files on PR #1; no `ADR-0NN` numeric refs exist.
- **No In-Progress ticket overwritten** (none existed). GGU-4's `Done` gate held — its description is byte-identical.
- **No status, label or priority changed** on any ticket.
- One recoverable failure: the GGU-4 comment first posted mangled (`addCommentToJiraIssue` takes raw text, not JSON-escaped text, unlike `editJiraIssue`'s `fields`). Fixed by updating comment `80041` **in place** — one retry, no loop, exactly one comment on the ticket.

## What was created

- **[GGU-46](https://somniosoftware.atlassian.net/browse/GGU-46)** — "Verify Firebase ID tokens on the backend (auth middleware + session identity)", split out of GGU-3.
- **16 issue links**, zero deletions. GGU-4 and GGU-45 are no longer orphans. `GGU-3 --split to--> GGU-46` records the split.
- **PR #1** — 9 ADRs, 3 contract specs, this report. Authored in an isolated `git worktree`, never in the user's checkout.

### The iOS/Android ticket was NOT created — deliberately

`GGU-27` (Epic 4) already exists and *edits* `ios/Runner/Info.plist` and `android/app/…`, presuming those directories. But creating them is literally what GGU-1's title and AC1 say. Folded into GGU-1 (est 3h → 4h) and linked `GGU-1 blocks GGU-27`. Idempotent-create rule working as intended: reuse over duplication.

### The backend-restructure ticket was NOT created — folded into GGU-45

Per the TL's ADR-C decision. GGU-45 does the `src/` packaging move; layering is deferred until after GGU-5 exists.

## Conflicts caught and resolved during execution

1. **`app_test.dart` was assigned to both GGU-45 and GGU-1** by the two upstream analyses. Resolved as sequential: GGU-45 creates it (so the gate is not green-on-nothing), GGU-1 updates it during the package rename. Both tickets now say so, so no one creates a duplicate.
2. **`test_session_isolation.py` name collision** — GGU-3 and GGU-5 both planned it. Split by concern: GGU-46 owns `test_session_identity.py`, GGU-5 owns `test_portfolio_isolation.py`. The collision is called out in-ticket so a future reader does not "restore" the old name from the snapshot's own Technical Design.

## ⚠️ Open scheduling risks surfaced during execution (for the TL)

These are real and the wave plan does not express them:

1. **GGU-46 needs GGU-3's `build_app()` extraction, not all of GGU-3.** No integration test can construct the Starlette app until it lands, so the extraction must ship as its own PR **early in Wave 1** — "GGU-3 is done" is too coarse. Recorded as GGU-3 OD-3.
2. **The `fail_under` ratchet has no guaranteed ordering.** GGU-45 sets 50, GGU-3 raises to 60, GGU-5 raises to 80 — but GGU-5 PR1 runs in Wave 1 *parallel with* GGU-3, so it may land before the 60 step. Pin the ratchet to a single owner or make it monotonic-by-construction.
3. **GGU-2 is forced strictly between GGU-3 and GGU-46** and no wave assignment says so: GGU-2's provisioning script needs `firebase-admin`, which GGU-3 adds, while GGU-46 needs GGU-2's token contract.
4. **GGU-12 still cannot close inside Epic 0** — `firebase.json` has `authorizedDomains: ["localhost"]`, so prod web login fails until GGU-29 (Epic 4). Either pull that change forward or accept the cross-epic dependency.

## Escalations — all four closed by the TL on 2026-09-18

Navigator (not `go_router`) · portfolio as a live object behind `get_portfolio`/`save_portfolio` · no uid allow-list, email/password sole provider (ADR-B D-5a) · Cloud Run `max-instances=1`. Plus ADR-C resolved into GGU-45 and the GGU-3 split confirmed.

## Remaining before Wave 1 starts

1. **Merge PR #1**, then upgrade every "pending ADR" Open Decision in the 7 tickets to a real citation.
2. **Ratify ADR-A** (session identity) — the isolation fix. Its rulings are already written into GGU-46's scope and ACs.
3. **~30 minutes with the spike author** for ADR-D findings 5 (web render behaviour under genui's *Limited* support — the project's stated top risk) and 6 (API churn). Neither is derivable from code; an agent that invents them is worse than a blank section.
4. **Assign an owner to `tasks/cancel`** — it always raises `UnsupportedOperationError` while the client calls it on every cancellation (ADR-D D-9).
