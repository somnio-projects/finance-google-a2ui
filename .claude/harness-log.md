# Harness log

One entry per iteration (PR). Newest first. Record what changed in the code
**and** in the harness (CLAUDE.md, rules, hooks, commands, agents, ship gate,
specs, docs), plus what the next person needs to know. This file is the
repository-side memory; the agent's private memory mirrors the decisions.

---

## 2026-09-19 — GGU-3 A2A surface · spec `specs/backend/0010-a2a-surface.md`

**Branch:** `feat/GGU-3_a2a_surface`, stacked on GGU-14. Five deep.

**Why it mattered most.** The agent host ran a turn, the presentation layer
shaped payloads, the prompt taught the model both catalogues — and **none of
it was reachable**. Every one of those tickets had merged as code nothing could
invoke. This is the surface that makes them real.

**Code**
- `api/agent_card.py` — `GET /.well-known/agent-card.json`, **public**.
- `api/a2a.py` — `POST /`, JSON-RPC, answering `text/event-stream`.
- `services/a2a_service.py` — the thin adapter (ADR-J D-2). `AgentService`
  still does not know the protocol exists, which is what lets A2A move (it is
  alpha) without the services moving with it.
- `services/agent_card_service.py` — skills generated from the tool registry,
  same principle as the prompt catalogues.
- `api/middleware/install.py` — lifted out of `bootstrap.py`, which the change
  pushed over the budget. Middleware **order is a security contract**, so it
  says so where it now lives.

**Two error shapes, on purpose.** A fault *inside* the protocol is a JSON-RPC
error object at HTTP 200. A fault *before* the envelope is reached — no token,
rate limit — is still an RFC 9457 problem document at its real status. The
manual run shows both. A client parses two shapes and the spec says so rather
than letting it be discovered.

**A second public route.** The agent card is the first addition to the
unauthenticated list since the health probes. `.claude/rules/backend/security.md`
requires a spec note and sign-off, so both exist, and the contract test's
exemption is now a **named `PUBLIC` constant** with the reason attached —
previously a bare set literal inline in one assertion. Adding a public route is
now a visible diff rather than a route that quietly stops declaring a 401.

**Verified**
- `make gate`: **546 tests**, 100 % branch coverage, pylint 10.00/10.
- Live server: the card reads unauthenticated and advertises
  `https://api.finance-a2ui.example` (the **public** URL, ADR-D D-7 — the
  sample advertised `0.0.0.0`) with both tools as skills; a turn streams
  `working` → `message` → `completed`; `POST /` without a token answers a 401
  problem document; `tasks/cancel` answers `-32004` and an unknown method
  `-32601`, both at HTTP 200.

**Next person should know**
- **Every turn currently starts with empty history.** `contextId` is echoed,
  never resolved — sessions are GGU-46, on a different branch. The resolution
  rule is already decided and unchanged (resolve against the subject or treat
  as unknown).
- **The stream is well-formed but not incremental.** `run_turn` returns a
  finished turn rather than yielding, so the events arrive in one burst.
  ADR-K D-19 wants per-surface streaming; making the loop a generator changes
  `a2a_service.py` only.
- **ADR-D is still `Proposed`.** This implements D-1, D-2, D-3, D-7 and D-9 as
  written. If ratification moves any of them, this surface moves too (spec
  OD-5). Treating a proposal as a decision silently would have been the easy
  mistake.

---

## 2026-09-19 — GGU-14 system prompt · spec `specs/backend/0009-prompt-fragments.md`

**Branch:** `feat/GGU-14_prompt_fragments`, stacked on GGU-36. Four deep.

**The gap.** Two halves existed and nothing joined them: `agent/prompt.py`
held the rules, `presentation/prompt.py` could render the projection registry
as text, and the turn loop imported the rules as a constant and **sent neither
catalogue**. The model was told it must pick a registered view and never told
which views exist.

They were never joined because they cannot be: `app.agent` may not import
`app.presentation` (asserted over the parsed source). A **service** is where
they meet, which is what `services/prompt_service.py` now is.

**Both catalogues are generated.** The views came from the registry already
(ADR-K D-14); the tools now do too. Registering a tool or a view is what
teaches the model about it — there is no list to forget to update. The rules
that stay hand-written deliberately **name no tool**: a rule saying "for a
why-did-it-move question call `compute_attribution`" reads better and is the
one line guaranteed to go stale, so a test asserts the rules mention no
registered tool name (spec OD-1).

**Also split:** `services/agent_telemetry.py`. The turn loop was already at the
150-line ceiling — the reviewer of GGU-47 flagged it — and observability is the
part that grows every time someone wants one more counter. It answers a
different question from the loop: what an operator gets to see.

**Verified**
- `make gate`: **527 tests**, 100 % branch coverage, pylint 10.00/10.
- Printed the real prompt: 2,585 characters, both tools and both views present
  with their option bounds, generated from the two registries.

**Next person should know**
- `AgentService` no longer imports `SYSTEM_PROMPT`; it receives the built
  prompt. The turn-loop tests inject their own, which is deliberate: the loop's
  job is to send whatever prompt it was given, and pinning the real text there
  would make every prompt edit break the turn-loop suite.
- The prompt is built **once at startup**, so adding a tool needs a restart —
  which is true of registration anyway (spec OD-4).

---

## 2026-09-19 — GGU-36 attribution tool · spec `specs/backend/0008-attribution-tool.md`

**Branch:** `feat/GGU-36_attribution_tool`, stacked on GGU-49 (which is itself
stacked on GGU-47). Three deep, which is the direct cost of shipping four
tickets before any of them merges — worth naming rather than hiding.

**The distinction the ticket turned on.** Flow A asks *"why did my portfolio
move this week?"*. The existing `attribution.waterfall.v1` projection walks
each holding's **unrealised P/L** — a comparison against what the position
*cost*. The question asks about what it was *worth seven days ago*. A holding
bought two years ago can be deeply profitable and have contributed nothing this
week. Conflating the two would have put a confidently wrong chart in front of a
reviewer, so this ticket adds a genuinely new domain computation rather than
reusing the one that was already there. Recorded as spec OD-3: whoever builds
the window projection gives it **its own id** instead of changing what `v1`
means.

**Code**
- `app/domain/attribution.py` — pure `attribute_window(portfolio, window,
  symbols)`. The totals are derived *from* the contributions, so the waterfall
  closes structurally rather than by rounding luck.
- `app/agent/tools/attribution.py` — the `compute_attribution` tool: a closed
  set of windows, an optional symbol filter, `extra="forbid"`, and output that
  is entirely `*Display` strings.

**Two facts that look like bugs and are not** (both pinned by tests, both in
the spec):
- **The money closes exactly; the shares do not.** `contribution` is a
  subtraction of exact amounts. `share` is a division, and division is inexact
  in any finite base — the shares land one unit in the last place away from 1.
  The chart is drawn from the contributions. A test says so, so nobody later
  "fixes" the closure by rescaling the ratios.
- **A share can exceed 100 % or go negative.** When holdings move in opposite
  directions, one contributed 132 % of the net move while another offset
  −32 %. That is what a waterfall shows and it is correct. Clamping it would
  misstate the answer.

**Verified**
- `make gate`: **518 tests**, 100 % branch coverage, pylint 10.00/10, no CVEs.
- Manual run of the tool: the 7-day window reports `-$3,175.95` / `-4.66%`,
  the bars sum to exactly `-3175.950000000000`, `closes()` is True, a filtered
  BTC+ETH 30-day run still closes against its own total, and two identical
  calls produce identical payloads.

**Next person should know**
- Windows are a **closed set** (`1d`/`7d`/`30d`), not a free-form duration.
  The seeded history is 90 days, so a free-form window would let the model ask
  for a year and get a silently truncated answer. The closed set makes the
  refusal explicit (spec OD-4).
- One test in the first draft asserted nothing meaningful (a `max()` over a
  constant, then `!= []`). The testing rule forbids exactly that, and it passed
  anyway — worth re-reading your own new tests for it, because a green suite
  will not tell you.

---

## 2026-09-19 — GGU-49 presentation layer · spec `specs/backend/0005-presentation-layer.md`

**Branch:** `feat/GGU-49_presentation_layer`, **stacked on `feat/GGU-47_agent_host`**
(see *Why this one is stacked* below). Built by a worktree agent in parallel
with GGU-47 and GGU-48.

**Code** — implements [ADR-K](../docs/adr/ADR-K-response-shaping.md) end to end:
`presentation/{registry,spec,fragments,displays,options,selection,prompt,contract,resolve,errors,sample,surfaces}.py`
plus two reference projections in `presentation/views/`, the `/v1/views`
catalog, `?view=` on a portfolio read, and the agent-facing render intent.

**Decisions worth knowing**
- **`views/` is auto-discovered** (`pkgutil.iter_modules`), not a hand-kept
  import list. The presentation rule blessed "one import line in the package
  `__init__`"; the ticket said *no* shared file may be edited to add a chart.
  Discovery satisfies both, and adding a chart is now literally one new file.
- **Options are shared across a multi-view request.** `?view=a&view=b` works,
  but `?view=attribution.waterfall.v1&top_n=3` is a **422** because the
  waterfall declares no `top_n`. Per-view namespacing would need a query-string
  interpreter, which ADR-K D-3 rejects; per-entry options belong to
  `POST /v1/view-renders` (D-18, out of scope).
- **`currency` is `Literal["USD"]`.** The backend invents no FX rate, so `EUR`
  is an honest 422 rather than a fabricated figure.
- **Selection stays additive**: each projection declares `fitness(portfolio)`
  and the rule ranks the registry — no `if/elif` on ids.
- **OpenAPI examples are rendered from the registry at operation level**, not
  hand-copied into `json_schema_extra`: a schema-level example would have to
  exist before the DTO class is complete.

**Why this one is stacked on GGU-47 rather than cut straight to `develop`.**
Built in parallel, the two tickets each created the piece the other also
needed. ADR-E D-2 allows exactly **one** formatting module and both had one;
the duplicate-code gate allows one AST helper for the boundary tests and both
had one. Landing them side by side would have merged that duplication into
`develop` and left someone to find it later. The integration commit on this
branch resolves it instead:

- `app/core/display.py` becomes the single `Decimal` → string boundary for both
  layers, carrying GGU-49's locale support and GGU-47's explicit sign.
  Quantities take a `trim` flag because a chart axis wants `"0.60000000"` and a
  sentence the model reads aloud wants `"0.6"`. `presentation/formatting.py` is
  gone.
- The locale table, the rounding and the digit grouping move to
  `app/core/locales.py` — *what kind of number this is* and *how digits are
  written in a place* are different questions, and together they broke the
  150-line budget.
- `tests/boundaries.py` is the one AST reader for the domain, agent and
  presentation suites; `tests/unit/import_graph.py` is gone.
- The portfolio provider is a **container** field, not a member of
  `AgentRuntime`: both the agent's tools and the projections read the same
  portfolios.
- **`app/api/deps` is now a package.** Merging both tickets' providers put the
  single file at 168 lines. Controllers still write
  `from app.api.deps import ...` unchanged, and services are still constructed
  in one place — it is one directory instead of one file.

**Verified**
- `make gate` after the rebase: **485 tests, 100 % branch coverage**, pylint
  10.00/10, interrogate 100 %, deptry clean, no CVEs.
- Manual run against the compose Postgres: two projections in one request;
  an undeclared option → 422 problem+json; `currency=EUR` → 422; no `view`
  named → the selection rule chose; unknown view → 404; another portfolio →
  404; no token → 401; `/v1/views` listed both projections with their options
  schemas; OpenAPI showed the `oneOf` with a `discriminator` and one example
  per member.

**A third duplication, found by auditing the merged result.** After both
branches were integrated, `total market value` was computed in **three**
places — the agent's `holdings_summary` tool and both projections — and the
`Portfolio` aggregate that owns the data exposed no total at all. None of them
was wrong, which is the point: they agreed only because three separate pieces
of code happened to be right. In a finance demo the agent says one of those
numbers out loud while a chart draws another, so *drift between them is the
most embarrassing failure available*. `Portfolio` now owns
`total_market_value()`, `total_cost_basis()` and `total_unrealized_pl()`, and
the three call sites read them. The residual "Other" bucket in the allocation
chart keeps its own sum — that one really is a chart concern.

Every pre-existing projection and tool test passed unchanged afterwards, which
is the evidence that the three implementations had been computing the same
figure.

**Next person should know**
- **`app/api/deps.py` no longer exists** — it is `app/api/deps/`. The
  architecture rule and `backend/CLAUDE.md` still name the file; they are
  correct about the *rule* (one place constructs services) and stale about the
  path. Fix the wording when you next touch them.
- Adding a chart is one file under `presentation/views/`. A test proves it:
  it defines `cash.runway.v1` inside the test body and finds it in the
  registry, in `GET /v1/views` and in the generated prompt fragments.
- `test_openapi_contract.py` was split — the projection assertions live in
  `test_openapi_projections.py` because the 150-line budget would not hold
  both. Same gate, two files, with a pointer in the original docstring.
- This entry and GGU-47's were written during integration, not by the building
  agents: the sandbox denies writes to `.claude/` inside an agent worktree.

---

## 2026-09-19 — GGU-47 agent host · spec `specs/backend/0006-agent-host.md`

**Branch:** `feat/GGU-47_agent_host` → `develop`. Built by a worktree agent in
parallel with GGU-49 (presentation) and GGU-48 (delivery), with
non-overlapping file ownership agreed up front.

**Why the ticket existed at all.** The board had tickets for the prompt
fragments (GGU-14), the deterministic tools (GGU-36–39) and the transport
(GGU-3), but nothing owned the piece that ties them together. The deleted ADK
sample provided it for free; the FastAPI baseline does not. Without it every
tool ticket would have merged as an unreachable pure function.

**Code**
- `core/model.py` (conversation DTOs), `core/display.py` (the single
  `Decimal` → string boundary), `core/protocols.py` gains `ModelClient`.
- `agent/{contracts,registry,prompt}.py` and `agent/tools/holdings_summary.py`
  — tools register from their own module, so adding one never edits a shared
  file. That seam is what GGU-37/38/39 depend on.
- `infra/model/{payload,gemini_client,null_client,factory}.py` — the Gemini
  adapter behind the Protocol, plus a deterministic `NullModelClient` wired
  exactly like the existing `ErrorReporter`/`NullErrorReporter` pair.
- `services/agent_service.py` (the turn loop) and `services/agent_tools.py`
  (tool execution and failure masking, split out to stay inside the budget).

**Decisions worth knowing**
- **httpx, not the `google-genai` SDK.** No new dependency, no new pip-audit or
  deptry surface, and the adapter mirrors `JwksKeyResolver`, a pattern already
  proven in this codebase. Swapping to the SDK later is one module.
- **The render intent is declared, not resolved.** `agent/contracts.py` defines
  only `{view, options}` (ADR-K D-11). Validating it against the projection
  registry and falling back on rejection is ADR-K D-12 and belongs to GGU-49 —
  which is why the two tickets could run in parallel at all.
- **One formatting module.** `core/display.py` sits in `core` because it is the
  only place both `app/agent` and `app/presentation` may import (ADR-E D-2).
  **The presentation layer must reuse it rather than add a second formatter.**
- **The iteration bound counts model calls, not tool calls** (default 4: one
  plan plus three corrections). On exhaustion the turn answers a fixed message
  and sets `truncated=True`, rather than emitting half a sentence.
- **A misbehaving tool never fails the turn.** The model receives
  `{"error": ...}` and another iteration; only the exception object reaches the
  `ErrorReporter`. An unknown tool is not reported at all — it is the model's
  mistake, not ours.
- `AgentRuntime` groups `model`/`tools`/`portfolios` in `api/container.py`:
  three more singletons would have pushed `Container` past pylint's attribute
  limit.

**Verified**
- `make gate`: 348 tests, 100 % branch coverage, pylint 10.00/10, interrogate
  100 %, deptry clean, no CVEs.
- **Mutation check** (required whenever error masking changes): removing the two
  `except` clauses in `gemini_client.py` turned 9 tests red; restored → 32
  green.
- Manual run of a full turn against `NullModelClient` with a tool call: the
  tool result was fed back to the model on the second call, the turn answered
  with the pre-formatted figures, and the telemetry line carried
  `model`/`outcome`/`duration_ms`/`iterations`/`tool_calls` and **no** prompt,
  answer or subject.

**What review changed.** The `backend-reviewer` agent approved it with no
blockers and eleven should-fixes. Four were rule violations and are fixed here:
`backend/docs/SECURITY.md` still described the model key as living in a "future
spec", `backend/docs/OBSERVABILITY.md` did not list the new metric or events,
`docs/diagrams/01-system-context.md` still drew Gemini as "(planned — GGU-47)"
in the ticket that ships it, and the spec was `Draft` and missing from
`specs/README.md`. The remaining seven are recorded as **OD-7 … OD-12 in the
spec** rather than fixed here, each with the ticket that should fix it. The one
worth reading is **OD-7: the Gemini wire format has never met the real API** —
every test runs against stubs we wrote, so 100 % coverage proves the code
matches *our assumption* of the format. GGU-3 carries the first live call and
should treat a mapping fix as expected.

**Next person should know**
- **There is no HTTP route yet.** `api/v1/`, `router.py` and the OpenAPI
  document are untouched by design; `get_agent_service` and `get_tool_context`
  wait in `deps.py` for GGU-3 to expose the A2A surface (ADR-J D-2).
- The default model id is `gemini-3.8-flash`, the only pin recorded in the repo
  (ADR-D D-4). Nothing depends on it; `GEMINI_MODEL` overrides.
- `tests/unit/import_graph.py` now holds the shared AST helpers that the domain
  and agent boundary tests both use — pylint's duplicate-code check forced the
  extraction, and the presentation layer's boundary test should reuse it too.
- This entry was written during integration, not by the building agent: the
  sandbox denies writes to `.claude/` inside an agent worktree. Budget for that
  when delegating.

---

## 2026-09-19 — GGU-5 portfolio domain · spec `specs/backend/0003-portfolio-domain.md`

**PR:** #12 · **Built by a worktree agent**, integrated and verified here.

**Code**
- `src/app/domain/` — 16 modules, each ≤150 lines: `money` (Decimal end to end,
  float rejected at the boundary), `terms` (long = **strictly more than 365 days**,
  leap year asserted), `lots`, `holdings`, `transactions`, `prices`/`history`
  (deterministic **90-day** daily series ending on the current price),
  `market` (curated reference — the deleted `crypto_data.json` is gone and the
  domain is now the **single source of price**), `invariants` (exact Decimal
  equality; weights within 0.0001), `portfolio`, `seed`, `provider`.
- `PortfolioProvider` Protocol + in-memory implementation: portfolios are
  per-subject and `as_of` is fixed at first access, so a lot cannot flip term
  mid-demo. No `datetime.now()` anywhere — a test parses the AST to prove it.

**Decisions recorded in the spec**
- OD-1 (blocked GGU-5): 90-day window, answered by GGU-36's owner in Jira.
- `Portfolio` is a frozen dataclass, not a pydantic model — a `validate()` read
  method would shadow pydantic's deprecated `BaseModel.validate`.
- `price_series`: `min(window, 89)+1` points, truncates above history,
  `window=0` → 1 point, negative → `WindowOutOfRangeError`.
- `provider.get` **seeds** instead of raising for an unknown subject: a demo
  session must not open on an error, and that is what fixes `as_of`.
- Divergence from ADR-C D-7 (stdlib logging): the provider uses
  `app.core.logging` because this backend configures structlog in `bootstrap`;
  D-7 was written for the deleted `backend_python/`.

**Next person should know**
- The shared dev database was stamped at revision `0004` by the GGU-46 worktree
  while this branch only has `0001`–`0003`; run the suite with testcontainers
  (the default) or re-create the local volume.
- `docs/specs/GGU-5/domain-contract.md` (written before the rewrite) is
  superseded by spec 0003 §8 — it should be marked as such when GGU-46 lands.

---

## 2026-09-19 — REST + OpenAPI contract, quality tooling, CI redesign

**Decisions (Lautaro):** every endpoint strictly RESTful and *exhaustively*
documented in Swagger; add every tool that keeps the code impeccable and run
them in a pre-commit hook; make CI cheap and readable; all PRs go to `develop`.

**Code**
- `api/openapi.py` — one place for problem responses, tag metadata and the API
  description; controllers compose from it instead of repeating `responses=`.
- Every operation now carries `operation_id`, `description`, `tags`, full
  `responses` (problem+json per status) and examples; every DTO field and query
  parameter has a description, an example and a bound.
- `GET /v1/me/audit` → **`GET /v1/me/audit-events`** (plural resource noun).
- `tests/unit/api/test_openapi_contract.py` makes the rule enforceable: a route
  without summary/description/operation_id/tags/responses fails the gate.

**Harness**
- `.claude/rules/backend/api-design.md` (REST semantics, OpenAPI completeness, DRY).
- `.claude/rules/ci-conventions.md` (where a check belongs, job/step naming,
  cost rules, "change one → change all three").
- `make quality` = xenon · vulture · interrogate (100 % docstrings) · deptry ·
  pylint (duplication + design limits) · codespell, wired into `make gate`,
  `.pre-commit-config.yaml` and CI.
- `.pre-commit-config.yaml` rewritten: hygiene hooks (incl. `check-added-large-files`
  and `no-commit-to-branch main,develop`), gitleaks, ruff, codespell, actionlint,
  `terraform_fmt`, local typecheck/budget/quality/unit-tests, and `make gate` on pre-push.
- `backend-ci.yaml` rewritten as four readable jobs (Quality · Tests · Security ·
  Container) plus a `Report` job writing a table to the run summary; PostgreSQL as a
  **service container** instead of testcontainers; `image` needs the cheap jobs.
- Branch model: `develop` is the integration branch, `main` release-only.

**Next person should know**
- `pre-commit install && pre-commit install --hook-type pre-push` once per clone.
- Adding an endpoint without full OpenAPI metadata now fails `make gate`, not review.
- `starlette` became an explicit dependency (deptry caught the transitive import).

---

## 2026-09-19 — Audit remediation: compliance corpus, admin MFA, retention purge

**PR:** https://github.com/somnio-projects/finance-google-a2ui/pull/2 (reviewer `mcampbell-somnio`).

**Trigger:** first full Somnio CLI audits on the foundation — `soc2-audit`
40/100, `iso27001-audit` 64/100, `python-best-practices` 88/100 (the earlier
`security-audit` 98 measured only technical controls). Lautaro's standing rule:
every audit > 90 before the PR.

**Code**
- `JwtClaims` / `JwksDocument` pydantic boundary models; `core/dto.py::from_row`
  (corrupt row → typed 503); `FeatureFlagCache.get` and `JwksKeyResolver.key_for`
  are pure queries; `Final` constants; `create_app` split; fixture/`autospec`/ids
  fixes (PR #2).
- **Admin MFA**: `Principal.auth_methods` from the `amr` claim, `Principal.is_mfa`,
  `Settings.admin_mfa_required` (default = production), enforced in
  `FeatureFlagService._require_admin`.
- **Retention**: `AuditRepository.purge_older_than`, `AuditService.purge_expired`,
  `app/jobs/purge_audit.py` (`python -m app.jobs.purge_audit`, `make purge-audit`), `AUDIT_RETENTION_DAYS=400`.
- **IaC** (`infra/`, Terraform ~> google 6): the CLOUD_SERVICES §3 topology as code —
  validated locally and in `infra-ci.yaml` (fmt · validate · trivy config); **not
  applied** (no GCP project until GGU-29). Closes the SOC 2 Family F evidence gap
  honestly: the controls exist as reviewed code, status "apply pending".
- `backend-reviewer` round 2 (final tree) FLAGGED 2 blockers + 7 should-fix, all
  addressed: `audit_events.target` column (migration 0003) so `action` stays
  `<domain>.<verb>` and 100-char flag keys no longer overflow `String(64)`;
  `feature_flag.list` audited; `httpx2` justified in `pyproject.toml` (Starlette's
  TestClient needs it); purge job moved to `app/jobs/purge_audit.py` (typed,
  covered, run as a module — the image ships `src/app` only); spec 0002 aligned (MFA, target, test
  names, mutation check); docs synced; branch-protection claims corrected with
  the exported ruleset (`docs/compliance/evidence/`, enforcement disabled today);
  `Edit` deny added for the merged migration 0002.
- Run 4 of `python-best-practices` (90) → basedpyright now also reports
  `Any`/`ExplicitAny`, unknown parameter/lambda types, private usage and
  uninitialised instance variables (only 2 fixes needed); `KeyResolver` split
  into `ensure_fresh()` + `key_for()`; `AuditService`/`IdentityService`
  constructors keyword-only; integration `session` fixture disposes in `finally`.
- `api/router.py` documented as the single route registration point;
  `docs/ADDING_AN_ENDPOINT.md` recipe + controller template (Lautaro: "routes
  ready to declare endpoints with the harness next iteration").

**Harness / repo**
- `docs/compliance/` — 27 policy/runbook documents + `isms/` (scope, SoA with all
  93 Annex A controls, objectives, document control, internal audit program,
  management review, CAPA log, competence records). Owner/approver/version
  headers; honest status words (pentest and DPAs are *planned*, not claimed).
- `.github/CODEOWNERS`, `pull_request_template.md`, `scheduled-scan.yaml`
  (weekly pip-audit + SBOM, Trivy SARIF, gitleaks → issue on failure), Semgrep
  `sast` job in `backend-ci.yaml`; root `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  `CONTRIBUTORS.md`, `CHANGELOG.md`.
- First **restore drill executed** against the compose database (pass, ~1 s) —
  `docs/compliance/RESTORE_DRILL_LOG.md`.

**Verified locally before the PR (2026-09-19)**
- `make gate`: 177 tests, 100 % branch coverage, basedpyright strict (+6 rules), pip-audit clean.
- Mutation checks: `require_feature` gate (2026-09-18), MFA branch of `_require_admin` → red → restored green.
- `docker compose up --build` with `backend/.env` from the template: migrations at `0003`, uid 10001 read-only, 401/200 identity, flag toggle 200 → 404 → 403 → 200, 100-char key with `target`, `feature_flag.list` audited, `python -m app.jobs.purge_audit` runs in the image.
- Restore drill #1 (pg_dump → scratch DB → compare → drop) passed — `docs/compliance/RESTORE_DRILL_LOG.md`.
- `infra/`: `terraform validate` OK, `trivy config` 0 findings.
- Somnio CLI: security 98 · python-health 91 · python-best-practices 91 · soc2 40→78→93 (with IaC) · iso27001 64→86→92. **All five > 90.**

**Next person should know**
- Policies are approved by merge; the management review #1 is asynchronous in
  PR #2 by design — from #2 it is a meeting.
- Local admin tokens for a production-like run need `"amr": ["pwd","otp"]`.
- `make purge-audit` needs `DATABASE_URL`; in production it is a monthly job
  (GGU-29).
- `backend-reviewer` should check that a new column/DTO field appears in
  `docs/compliance/DATA_CLASSIFICATION.md` §2.

---

## 2026-09-19 — Feature flags for endpoints · spec `specs/backend/0002-feature-flags.md`

**Decision (Lautaro):** endpoints must be switchable on demand without a deploy.

**Code**
- `feature_flags` table (revision `0002`), `FeatureFlagRepository`,
  `FeatureFlagCache` (TTL, in the `Container`), `FeatureFlagService`
  (env kill-switch → cache → DB → default; `admin` scope for writes; audit
  event `feature_flag.update` with `target=<key>` + `feature_flag.toggled` metric).
- `api/feature_gate.py::require_feature(key, default=)` — route dependency
  answering 404 `feature-disabled`; `/v1/me/audit` is the first gated route.
- Admin API `GET/PUT /v1/admin/feature-flags[/{key}]`; settings
  `FEATURE_FLAGS_CACHE_TTL_SECONDS`, `FEATURE_FLAGS_FORCE_DISABLED`.
- Repositories now translate `OSError` (asyncpg connection refused) as well as
  `SQLAlchemyError` — a flag read against a down database falls back to the
  gate default instead of a 500.

**Harness**
- `backend/docs/FEATURE_FLAGS.md`; `backend/CLAUDE.md` gets the flag rule;
  `specs/README.md` index; compose/env.example variables.
- **Env policy (Lautaro, 2026-09-19):** `docker-compose.yml` carries only the
  topology; the backend service loads `backend/.env` through `env_file`
  (required — `cp backend/env.example backend/.env` once per clone). Env files
  live inside each solution and are git-ignored (`**/.env`, `**/.env.*`); the
  agent cannot create them (permission deny), a human copies the template.
  Compose stays backend-only until frontend work starts.

**Next person should know**
- Dark-launch a new endpoint with `default=False`; an admin flips it on.
- The gate runs before the route's own auth, on purpose (a disabled route
  does not advertise itself); the flag service never raises.

---

## 2026-09-18 — Backend foundation (FastAPI) · spec `specs/backend/0001-backend-foundation.md`

**Decision (Lautaro, TL backend):** replace the inherited Google ADK sample
(`backend_python/`) with a Somnio-standard FastAPI service in `backend/`. This
diverges from Jira GGU-45/ADR-C (`src/a2ui_crypto_market` packaging move) — the
tickets will be re-baselined against this foundation.

**Code**
- `backend/` created: layered FastAPI app (`api → services → repositories →
  models`, `bootstrap.py` composition root), Postgres via SQLAlchemy async +
  Alembic, bearer-token auth with pluggable verifiers (HS256 `jwt`, OIDC/SSO
  `oidc` via JWKS), audit trail table, RFC 9457 errors, request-id / security
  headers / body-limit / rate-limit middleware, Sentry behind an
  `ErrorReporter` Protocol, structlog JSON.
- 100 % branch coverage: unit suite with fakes, integration suite on a
  testcontainers PostgreSQL through real migrations.
- `Dockerfile` (non-root, read-only) + root `docker-compose.yml` (db + backend).
- `backend_python/` deleted.

**Harness**
- Root `CLAUDE.md` rewritten as an index; `backend/CLAUDE.md` is the backend
  operating manual.
- New rules `.claude/rules/backend/{architecture,security,testing,sdd}.md`
  (path-scoped); Python rules re-pointed from `backend_python/*.py` to
  `backend/**/*.py`.
- `.claude/settings.json`: PostToolUse hook `post-edit-check.py` (ruff +
  basedpyright + 150-line budget on edited backend files), `uv`/`docker
  compose`/`make` allowed, stale `pnpm` allows removed; the generated
  `claudeFlow`, `statusLine` and `model` blocks were dropped (unused tooling),
  the sandbox `excludedCommands` narrowed to `gh`/`gcloud`/`docker`/`open`/
  `osascript`; `Edit` denied on the merged Alembic revision and on `uv.lock`
  (new revisions are still creatable).
- `backend-reviewer` first pass (2026-09-18) FLAGGED 2 blockers + 7 should-fix;
  all addressed in the same PR: gitleaks allow on the fixture literal, 413/429
  via `problem_response` (request_id/instance), rate limiter keyed per IP
  **and** per token (rotating garbage tokens no longer buys budget), `Settings`
  rejects `*` in CORS and `*` hosts in production, readiness status decided in
  the DTO (no branching in the controller), `Principal` moved to `core/`,
  `main.py` no longer omitted from coverage, `make gate` now includes `audit`.
- `.claude/agents/backend-reviewer.md`, `.claude/commands/{feature,spec}.md`.
- `.claude/ship-gate.json` populated (6 backend commands = CI = `make gate`).
- `specs/` created (README, TEMPLATE, first spec); `docs/DEV_HARNESS.md`.
- CI: `.github/workflows/backend-ci.yaml` (gate + gitleaks + docker build).

**Verified locally before the PR**
- `make gate`: 121 tests, 100 % branch coverage, ruff/basedpyright/budget clean.
- Mutation checks: auth dependency and rate limiter disabled → the
  identity/middleware tests went red; restored → green.
- `docker compose up --build`: `/healthz` 200 with security headers, `/readyz`
  ready, `/v1/me` 401 problem+json without token and 200 with a token, audit
  row persisted, container uid 10001 on a read-only filesystem,
  `alembic check` reports no drift.

**Next person should know**
- `env.example` has no leading dot on purpose (the deny rule `**/.env.*`
  blocks the agent from creating templates too).
- List settings (`CORS_ALLOWED_ORIGINS`, `TRUSTED_HOSTS`) are comma-separated,
  not JSON — `CsvList` (`NoDecode`) in `core/config.py`. The compose stack
  caught this; a unit test now pins it.
- Async pytest fixtures use function loop scope; a session-scoped async
  fixture with asyncpg fails with "attached to a different loop".
- uv on this Mac needs `UV_LINK_MODE=copy` inside the sandbox; the Makefile
  exports it.
- Flutter gate is still a `_candidates` entry in `ship-gate.json` until
  GGU-45/GGU-1 land.
