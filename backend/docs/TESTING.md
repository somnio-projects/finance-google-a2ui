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
- Tests generate unique subjects (`uuid4`) and never depend on order.
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

```bash
docker compose up -d db
TEST_DATABASE_URL=postgresql+asyncpg://app:app@localhost:5432/finance make test
```
