# Harness log

One entry per iteration (PR). Newest first. Record what changed in the code
**and** in the harness (CLAUDE.md, rules, hooks, commands, agents, ship gate,
specs, docs), plus what the next person needs to know. This file is the
repository-side memory; the agent's private memory mirrors the decisions.

---

## 2026-09-19 — Feature flags for endpoints · spec `specs/backend/0002-feature-flags.md`

**Decision (Lautaro):** endpoints must be switchable on demand without a deploy.

**Code**
- `feature_flags` table (revision `0002`), `FeatureFlagRepository`,
  `FeatureFlagCache` (TTL, in the `Container`), `FeatureFlagService`
  (env kill-switch → cache → DB → default; `admin` scope for writes; audit
  event `feature_flag.update:<key>` + `feature_flag.toggled` metric).
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
