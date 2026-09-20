---
description: Backend testing contract — 100 % branch coverage, unit tests with fakes only, integration tests against real PostgreSQL via testcontainers, naming and fixture conventions. Loads when touching backend tests.
paths:
  - "backend/tests/**/*.py"
  - "backend/pyproject.toml"
alwaysApply: false
---

# Backend testing rules

## The bar

- `pytest --cov --cov-branch` over `src/app` must report **100 %**, with branches. The gate fails otherwise. Do not lower `fail_under`, do not add `omit` entries, do not sprinkle `# pragma: no cover` (allowed only for `if TYPE_CHECKING:` and `__main__` guards, with an inline reason). The only configured exclusions are `if TYPE_CHECKING:` blocks and Protocol method bodies (`...`) — see `exclude_also` in `pyproject.toml`.
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

## A documented property needs a test that bites

Three times in one iteration a property was written down, believed, and
enforced by nothing. Each was found by a human reading one file; none was
found by the gate. The pattern is worth naming because it does not look like
a bug — everything is green:

| What was claimed | What was true |
|---|---|
| `symbols` is bounded at ten characters per ticker (spec 0011 §5) | a 5 000-character ticker validated; the bound was in the JSON Schema the model reads, not in the model that enforces |
| the tool is registered and reachable (spec AC-1) | commenting out `register(...)` left the whole suite green and the tool invisible to the model |
| every operation documents an example (`api-design.md` §2) | eight operations did not, and the rule had never been checked |

So:

- **A property that spans two declarations gets a test comparing them.** An
  advertised bound and an enforced bound are two declarations of one fact.
  A comment saying they agree is not a test — it is where the hole hides.
- **Wiring gets a mutation check.** If removing one line (a `register(...)`,
  a `include_router(...)`, a middleware) leaves the suite green, that line is
  untested. Run it, confirm red, restore, and say so in the PR.
- **Prefer enforcing over the registry, not per instance.** `tests/unit/agent/
  test_tool_argument_bounds.py` walks every registered tool, so the next tool
  is covered the day it registers rather than the day someone remembers.
- **100 % branch coverage does not see a conditional expression.**
  `ZERO if ratio is None else ratio` was fully "covered" and never once
  executed with `None`. Assert documented rules directly.

## A payload is wrong when two of its own numbers disagree

Every figure can be individually correct and the answer still false, because
a reader multiplies, subtracts and compares across the row:

- a price rendered `$0.13` beside a market value it does not multiply back to;
- a `positionValue` **rising** beside a profit that is **falling**;
- a break-even string shared with twenty-five losing rows.

Unit tests that check one figure at a time cannot see any of these. When a
payload puts figures next to each other, **assert the relationship**, not just
the parts.

## Mutation check for security code

When you touch authentication, rate limiting or error masking, prove the test bites: comment the middleware/guard out, run the affected tests, confirm they go red, restore. Say so in the PR under `Test decision:`.
