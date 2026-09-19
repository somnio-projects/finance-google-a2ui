# Harness log

One entry per iteration (PR). Newest first. Record what changed in the code
**and** in the harness (CLAUDE.md, rules, hooks, commands, agents, ship gate,
specs, docs), plus what the next person needs to know. This file is the
repository-side memory; the agent's private memory mirrors the decisions.

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
