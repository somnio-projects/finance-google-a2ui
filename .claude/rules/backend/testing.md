---
description: Backend testing contract — 100 % branch coverage, unit tests with fakes only, integration tests against real PostgreSQL via testcontainers, naming and fixture conventions. Loads when touching backend tests.
paths:
  - "backend/tests/**/*.py"
  - "backend/pyproject.toml"
alwaysApply: false
---

# Backend testing rules

## The bar

- `pytest --cov --cov-branch` over `src/app` must report **100 %**, with branches. The gate fails otherwise. Do not lower `fail_under`, do not add `omit` entries, do not sprinkle `# pragma: no cover` (allowed only for `if TYPE_CHECKING:` and `__main__` guards, with an inline reason).
- Every behaviour has a test that would fail if the behaviour broke — executing a line is not testing it. Error branches (`except`, early returns, 4xx/5xx paths) are tested explicitly.

## Two suites, two rules

| Suite | Marker (auto-applied) | Talks to | Doubles |
|---|---|---|---|
| `tests/unit/**` | `unit` | nothing outside the process | `FakeReporter`, `FakeVerifier`, `FixedClock`, in-memory repository fakes, `mocker.patch(..., autospec=True)` |
| `tests/integration/**` | `integration` | PostgreSQL (testcontainers or `TEST_DATABASE_URL`) through the real app | none for the database; `FakeReporter` for telemetry |

Unit tests of the HTTP layer build the real app with `tests/unit/api/conftest.py::make_app` and the unreachable DSN (`127.0.0.1:1`). Anything that needs a row in the database belongs in `tests/integration`.

## Conventions

- Files mirror `src/app` (`tests/unit/services/test_audit_service.py` ↔ `src/app/services/audit_service.py`).
- Names: `test_<unit>_<scenario>_<expected>`. `@pytest.mark.parametrize` always with `ids=`. `pytest.raises` always with `match=`.
- Fixtures in the nearest `conftest.py`, function-scoped unless provably read-only (the Postgres container is the one session-scoped fixture).
- Unique data per test (`uuid.uuid4()` in subjects/ids); never shared literal ids.
- Time comes from `FixedClock(FROZEN_NOW)`; tokens from `make_token(...)`; never `sleep` to expire a token — mint it expired.
- Patch at the import site of the module under test (`app.infra.telemetry.sentry_reporter.sentry_sdk.init`), with `autospec=True`.
- Settings come from `make_settings(**overrides)`; never read `.env` in tests.

## Mutation check for security code

When you touch authentication, rate limiting or error masking, prove the test bites: comment the middleware/guard out, run the affected tests, confirm they go red, restore. Say so in the PR under `Test decision:`.
