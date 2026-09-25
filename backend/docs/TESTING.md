# Testing

## The gate

```bash
make gate      # ruff check · ruff format --check · basedpyright · file budget · pytest --cov --cov-branch (fail_under = 100)
make audit     # pip-audit
```

Coverage is measured on `src/app` with **branch** coverage and must be 100 %.
Nothing is omitted — `src/app/main.py` is covered by `tests/unit/api/test_bootstrap.py`.

## Suites

| Suite | Path | Marker | Needs |
|---|---|---|---|
| Unit | `tests/unit/**` | `unit` (auto) | nothing — fakes only |
| Integration | `tests/integration/**` | `integration` (auto) | Docker (testcontainers `postgres:16-alpine`) or `TEST_DATABASE_URL` |

Run one: `uv run pytest -m unit --no-cov` / `uv run pytest -m integration --no-cov`.

### Unit

- Doubles live in `tests/conftest.py`: `FakeReporter` (records metrics and
  exceptions), `FakeVerifier` (accepts token `good`), `make_settings(**over)`,
  `make_token(...)` (HS256 tokens for the test issuer/audience), `FROZEN_NOW`
  + `FixedClock`.
- HTTP-layer unit tests build the real app through
  `tests/unit/api/conftest.py::make_app` with a DSN on port 1, so a route that
  accidentally touches the database fails fast.
- `pytest-mock` with `autospec=True`, patched at the import site
  (`app.infra.telemetry.sentry_reporter.sentry_sdk.init`).

### Integration

- `tests/integration/conftest.py` starts PostgreSQL once per session, runs
  `alembic upgrade head` (the production path), then builds the app with the
  real JWT verifier and a `FakeReporter`.
- **`_empty_database` is autouse: every DB-backed test starts against an empty
  database.** It deletes every row of every migrated table *before* the test
  body, not after, so a test that commits needs no cleanup of its own and an
  interrupted run cannot poison the next one. This is what makes `make test`
  runnable twice against one database; before GGU-124 it was not (spec
  [`backend/0047`](../../specs/backend/0047-the-db-backed-suite-cleans-up-after-itself.md)
  records why emptying rather than an outer-transaction rollback).
- Tests generate unique subjects (`uuid4`) and do not depend on order. The one
  deliberate exception is the pair in
  `tests/integration/test_fixture_isolation.py`, which shares a literal e-mail
  on purpose: what one test leaves behind for the next cannot be observed from
  inside a single test, and that handoff is the property GGU-124 was about.
  Both halves say so, and step 2 fails loudly if step 1 did not run.
- Repository tests open their own `session_scope` and roll back.

## Conventions

- `test_<unit>_<scenario>_<expected>`; `parametrize(..., ids=[...])`;
  `pytest.raises(..., match=...)`.
- One test module per source module, mirrored path.
- Never `sleep` for expiry — mint expired tokens with `make_token(ttl_seconds=1, now=FROZEN_NOW)`.
- `filterwarnings = error`: a warning is a failure. Fix the cause or filter a
  specific category with a comment.

## Mutation checks

For auth, rate limiting and error masking changes, disable the guard, run the
relevant tests, confirm they fail, restore. Note it in the PR under
`Test decision:`. A security test that still passes with the control removed
is not a test.

## Local database for manual testing

> **`make test` empties this database.** Since GGU-124 the integration fixtures
> delete every row of every migrated table before each test, so pointing
> `TEST_DATABASE_URL` at the compose database costs you whatever is in it —
> including the demo portfolio from `make seed`. Re-seed afterwards, or run the
> suite against its own throwaway container and leave the compose one for
> manual testing:
>
> ```bash
> docker run -d --name pg-scratch -e POSTGRES_USER=app -e POSTGRES_PASSWORD=app \
>   -e POSTGRES_DB=finance -p 55433:5432 postgres:16-alpine
> TEST_DATABASE_URL=postgresql+asyncpg://app:app@localhost:55433/finance make test
> ```
>
> Omitting `TEST_DATABASE_URL` entirely is the safe default: testcontainers
> starts and destroys its own PostgreSQL.

```bash
docker compose up -d db
TEST_DATABASE_URL=postgresql+asyncpg://app:app@localhost:5432/finance make test
```
