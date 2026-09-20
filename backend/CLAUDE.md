# CLAUDE.md — backend

FastAPI 0.141 · Python 3.12 · uv · SQLAlchemy 2 (async, asyncpg) · Alembic · PostgreSQL 16 · structlog · Sentry. Package `app` under `src/`. Part of the Somnio × Google A2UI showcase (Jira `GGU`). Read the root `CLAUDE.md` first; path-scoped rules for this folder live in `.claude/rules/backend/`.

## Run

```bash
cp backend/env.example backend/.env   # once; compose reads it via env_file, never committed
docker compose up --build          # from repo root: Postgres + API on :8000 (hot reload)
cd backend && make run             # API only, needs DATABASE_URL (same .env)
make migrate                       # alembic upgrade head
```

Docs at http://localhost:8000/docs (disabled when `ENVIRONMENT=production`).

## Verify — a change is not done without this

```bash
cd backend && make gate            # lint · typecheck · budget · catalog-check · quality · test 100 % · audit
cd backend && make quality         # code smells: complexity, dead code, docstrings, deps, duplication, typos
cd backend && make catalog         # regenerate docs/catalog/CONTRACT.md after touching a projection
```

- `make gate` == CI == `.claude/ship-gate.json`. Red gate = not done. Never lower `fail_under`, never add `# pragma: no cover` without a one-line reason.
- Integration tests start PostgreSQL via testcontainers (Docker required). `TEST_DATABASE_URL=postgresql+asyncpg://app:app@localhost:5432/finance` reuses `docker compose up db`.
- The PostToolUse hook runs ruff + basedpyright + file budget on every edited `.py` under `backend/`; the full suite runs in the gate.

## Layout and the pattern every file follows

```
api/v1/*.py          controller: resolve Depends, call ONE service method, return the DTO. No logic, no try/except.
api/deps.py          every Depends provider — the only place services are constructed per request
services/*.py        use cases; import schemas, repositories, core, auth — never fastapi/sqlalchemy
repositories/*.py    one per aggregate, subclass BaseRepository; the only code touching AsyncSession
models/*.py          SQLAlchemy entities, TimestampMixin + Base; one table per file
schemas/*.py         pydantic DTOs (frozen); never return ORM objects from a controller
auth/providers/*.py  TokenVerifier implementations; add a provider = new module + registry entry
agent/               agent host inner layer: Tool Protocol, registry, prompt; agent/tools/*.py
domain/              the portfolio aggregate (pure, Decimal); imports core only
infra/**             adapters (db engine/session, telemetry, model client); instantiated only in bootstrap.py
core/                Settings, AppError hierarchy, Protocols, logging, display — framework-free
bootstrap.py         the single composition root
```

Rules that are checked, not suggested:

- **150 lines per file** (`scripts/check_file_budget.py`). Over budget → split by responsibility, never by "part 1 / part 2".
- **Dependencies point inward**: api → services → repositories → models. Services never import FastAPI; repositories never import services.
- **Errors**: raise `app.core.errors.*` from services/repositories; the API layer turns them into RFC 9457 `application/problem+json`. Never `raise HTTPException` in a service, never leak SQLAlchemy/httpx/jwt exceptions upward (translate with `raise ... from exc`).
- **Config**: only through `Settings` (pydantic-settings, frozen). Required values have no default. Never `os.environ` in application code.
- **Auth**: controllers get the caller via `PrincipalDep`; the token is never read anywhere else, never logged, never stored (use `token_fingerprint`).
- **Persistence**: one `AsyncSession` per request (`get_session`), commit/rollback owned by `session_scope`. Schema changes ship with an Alembic migration in the same PR.
- **Telemetry**: report through the injected `ErrorReporter`; never `if sentry_configured:` at call sites (the null reporter handles absence). Same shape for the model: an unset `GEMINI_API_KEY` yields `NullModelClient`, so no call site branches on configuration.
- **Agent tools**: one module per tool under `app/agent/tools/`, ending in `register(MyTool())`; `load_tools()` discovers it. Adding a tool edits **no** shared file. Tools return pre-formatted `*Display` strings from `app/core/display.py` — the LLM never computes a figure. See `specs/backend/0006-agent-host.md`.
- **Feature flags**: gate a route with `dependencies=[require_feature("<domain>.<capability>")]` (`api/feature_gate.py`); dark-launch with `default=False`. Toggle via `PUT /v1/admin/feature-flags/{key}` (scope `admin`) or the `FEATURE_FLAGS_FORCE_DISABLED` env kill-switch. See `docs/FEATURE_FLAGS.md`.
- **REST + OpenAPI**: resource paths, correct verbs/status codes, and *every* operation carrying `summary`, `description`, `operation_id`, `tags`, `response_model`, the full `responses` map (problem+json per status) and examples; every DTO field documented and bounded. Shared response blocks come from `api/openapi.py` — never copy-pasted. See `.claude/rules/backend/api-design.md`.
- **Docstrings** on every public module/class/function (Google style, imperative). Type hints everywhere, `X | None`, built-in generics.

## Tests

- `tests/unit/**` — no I/O. Use the fakes in `tests/conftest.py` (`FakeReporter`, `FakeVerifier`, `make_settings`, `make_token`, `FixedClock`). Mirror the `src/app` tree.
- `tests/integration/**` — real PostgreSQL through Alembic migrations; the whole request path (`TestClient`).
- Coverage is 100 % **branch** coverage of `src/app`. New code lands with the tests that cover every branch, including error paths; a test that only executes lines without asserting behaviour is not a test.
- Every test is `test_<unit>_<scenario>_<expected>`; `parametrize` always with `ids`; `pytest.raises(..., match=)` always with `match`.

## Adding a feature (Spec-Driven Development)

1. Write `specs/backend/NNNN-<feature>.md` from `specs/TEMPLATE.md` (problem, scope, API contract, data model, acceptance criteria, test plan, security notes). Get it reviewed before code.
2. Migration → model → schema → repository → service → controller (`api/v1/<domain>.py`) → `deps.py` provider → `router.py` include, each with its tests. Recipe + controller template: `docs/ADDING_AN_ENDPOINT.md`.
3. `make gate` green, run the `backend-reviewer` agent, open the PR with `Spec:` and `Test decision:` lines, then append the iteration to `.claude/harness-log.md`.

`/feature <description>` packages this lifecycle.

## Security posture (SOC 2 / ISO 27001 — see docs/SECURITY.md)

Bearer-token auth on everything except `/health`, `/readyz`, `/openapi.json`, `/docs`; admin routes additionally require scope `admin`; feature-flag gates answer 404 before auth; strict security headers; CORS and `TrustedHost` allow-lists from settings; body-size limit; per-token rate limit; audit trail (`audit_events`) for identity actions; non-root read-only container; no secrets in code, images or logs; problem responses never carry stack traces.

## Do not touch

- `.env`, `.env.*` (denied by permissions). `env.example` is the template.
- `alembic/versions/*` already merged — write a new revision instead.
- `fail_under`, the ruff rule set, `typeCheckingMode` — changing the bar is a team decision, not a fix.
