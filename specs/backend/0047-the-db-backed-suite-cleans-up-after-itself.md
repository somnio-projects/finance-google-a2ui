# 0047 — The DB-backed suite cleans up after itself

- **Area:** backend
- **Status:** In progress
- **Ticket:** GGU-124 · **Related specs / ADRs:** `backend/0035` (the seed job), `backend/0041` (the provisioning job), `.claude/rules/backend/testing.md`, `.claude/rules/python/testing-integration.md`
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-25

## 1. Problem

`cd backend && make test` is not idempotent. Run it twice against the same
PostgreSQL and the first run is green while the second fails six integration
tests — measured identically on Python 3.12.13 and 3.14.5, so the interpreter
upgrade (#130) only *revealed* it. The six provision users and seed portfolios,
commit, and leave the rows behind, so their own next run collides with them:

```
tests/integration/test_portfolio_concurrency.py::test_an_owner_never_reads_another_owners_portfolio
tests/integration/test_provision_users_job.py::test_one_run_provisions_a_whole_audience
tests/integration/test_provision_users_job.py::test_the_job_provisions_end_to_end_through_its_own_session
tests/integration/test_seed_portfolios_job.py::test_one_run_seeds_a_whole_audience
tests/integration/test_seed_portfolios_job.py::test_a_different_email_gets_its_own_portfolio
tests/integration/test_seed_portfolios_job.py::test_the_job_seeds_end_to_end_through_its_own_session
```

**CI cannot see it.** `backend-ci` gives every run a fresh `postgres:16`
service container, so the suite always meets an empty database. The person who
meets it is a developer running the pre-push hook twice — and what they see
first is a **concurrency** test failing, which reads like a real race in
`PersistentPortfolioProvider` rather than like a fixture that did not clean up.
One defect producing a permanently green gate and a misleading red.

Underneath that: the suite's isolation was asserted by the *environment*, which
is the reverse of what `.claude/rules/python/testing-integration.md` rule 1 and
`.claude/rules/backend/testing.md` ask for. Nothing in `tests/` claimed it, so
nothing could fail when it stopped being true.

## 2. Scope

**In:**

- One autouse fixture in `backend/tests/integration/conftest.py` that hands
  every DB-backed test an empty database, and the helper it calls.
- Tests that assert the isolation itself, including the failure mode GGU-124
  describes, so the next job-runner test does not reintroduce it.
- This spec's §3 record of *why* emptying rather than rollback.
- The three documents that recommend running the suite against the **compose**
  database (`backend/docs/TESTING.md`, `backend/CLAUDE.md`,
  `docs/DEV_HARNESS.md`), amended: the command they print did not empty it
  before this change and does now. §5 has the reasoning.

**Out:**

- **A CI job that runs the suite twice against one service container** (the
  ticket's AC-3). It is the right idea and it is not in this PR: `.github/`
  and `scripts/check_gate_pairs.sh` are owned by a parallel branch, and a
  `repo.*`/`py.*` gate entry whose `cmd` is not byte-identical to a workflow
  step fails `repo.gate-pairs` (`.claude/rules/ci-conventions.md` §5). §9
  carries the proposal for whoever owns those files next.
- Touching the six tests. AC-2 is explicit that the fix is the fixture layer.

## 3. API contract

None — this changes no HTTP surface. The contract it changes is the fixture
contract of `tests/integration/`:

| Fixture | Scope | Contract |
|---|---|---|
| `database_url` | session | unchanged: a migrated DSN, `TEST_DATABASE_URL` or testcontainers |
| `engine` | function | **new** — one disposable `AsyncEngine`, shared by `_empty_database` and `session` so a test pays for one engine, not two |
| `_empty_database` | function, **autouse** | **new** — every row of every migrated table is gone before the test body runs |
| `session` | function | unchanged behaviour, now built on `engine` |

### Why truncation and not rollback — the decision the ticket asks to record

Wrapping each test in an outer transaction and rolling it back is the canonical
strategy, and it does not work here. It only reaches rows written through the
session the fixture handed out, and this suite writes through **four** paths:

| Path | Used by | Reachable by an outer-transaction rollback? |
|---|---|---|
| the `session` fixture | repository and job-loop tests | yes |
| the app's own engine in `build_container` | every `integration_client` test | no |
| a job's own `session_scope` | `test_the_job_*_end_to_end_through_its_own_session` | no |
| two genuinely concurrent sessions | `test_two_concurrent_first_accesses_produce_one_portfolio` | no — the point of the test is that they are separate transactions |

Three of the four would need the production composition root changed to accept
a caller-supplied connection, purely so tests could bind it. That is a test
concern reaching into `bootstrap.py`, and the fourth path cannot be made to
work at all: forcing those two sessions into one transaction deletes the race
`uq_portfolios_owner_email` exists to decide.

Emptying the tables asks the database what it holds rather than which session
put it there, so it covers all four at once and costs no production change.

Two sub-decisions inside it:

- **In setup, not teardown.** A test that commits is the normal case here, so
  "leave it as you found it" cannot be the session's rollback. Emptying on the
  way *in* additionally survives an interrupted run — a suite killed halfway
  cannot poison the next one — which emptying on the way out would not give.
  The cost is that a completed run leaves the last test's rows in the database;
  a developer inspecting it afterwards sees those, and every test still starts
  clean.

  Setup is **not** immune to the lock hazard, and an earlier draft of this spec
  claimed it was: a `DELETE` in setup waits on row locks held by a connection a
  *previous* failed test left open, for exactly the same reason a teardown one
  would. The interrupted-run argument carries the decision on its own. The
  hazard itself is handled rather than documented — the cleanup connection sets
  `lock_timeout` (`LOCK_TIMEOUT_MS`), so a stuck lock is PostgreSQL's own error
  naming the table instead of `make test` hanging with no output.
- **`DELETE` over `TRUNCATE`, and reflection over an enumerated list.** The
  table list is reflected from the database, so a table a future migration adds
  is covered the day it lands rather than the day somebody remembers this file
  — and reflection reads the *database*, not `app.models.__init__`. That second
  half is not hypothetical, and it is worth measuring rather than asserting:

  ```console
  $ uv run python -c "from app.models import Base; print(sorted(Base.metadata.tables))"
  ['audit_events', 'feature_flags', 'messages', 'sessions']
  ```

  **Four of the eight tables the migrations create.** `app/models/__init__.py`
  does not import `Portfolio` or `User`, so `Base.metadata` — which
  `alembic/env.py` hands to autogenerate as `target_metadata` — cannot see
  `users`, `portfolios`, `portfolio_lots` or `portfolio_transactions`. Building
  the cleanup on that list would have emptied half the database and reported
  eight names' worth of confidence. Reflection has no opinion about the import
  graph.

  That gap is a defect in its own right — `alembic revision --autogenerate`
  would propose **dropping** those four tables — and it is filed separately
  rather than fixed here, because it belongs to `models/` and to a migration
  review, not to a test fixture.

  `DELETE` in reverse `sorted_tables` order needs no `CASCADE` and no
  dynamically concatenated SQL string.

## 4. Data model & migration

None. No table, column, index or Alembic revision changes. Existing rows are
unaffected in every environment except a **test** database, whose contents this
spec is about.

## 5. Security notes

No change to authentication, authorization, scopes, audit events or rate
limits. One thing worth stating, because it is the only security-shaped
property here: the fixture deletes rows from whatever `TEST_DATABASE_URL`
points at, and it is reached only from `tests/integration/`, which is not
packaged (`[tool.hatch.build.targets.wheel] packages = ["src/app"]`).

**This is a genuine behaviour change and it is destructive.** Pointing
`TEST_DATABASE_URL` at a database with data now empties it. Before this spec,
the same command left the rows alone; `alembic upgrade head` against an
already-migrated database is a no-op, and `DELETE FROM` every table is not, so
"the exposure the suite already had" would be the wrong claim to make. Three
documents recommend exactly that command against the **compose** database —
`backend/docs/TESTING.md`, `backend/CLAUDE.md` and `docs/DEV_HARNESS.md` — and
all three are amended in this PR to say that `make test` empties it and that
`make seed`'s demo portfolio goes with it. The safe default is unchanged and now
stated: omit `TEST_DATABASE_URL` and testcontainers supplies a throwaway
database.

## 6. Acceptance criteria

1. **AC-1** — The fixture layer empties every migrated table between tests, over
   rows that are already **committed**, and refuses to report success when
   reflection finds too few tables to be a migrated database.
2. **AC-2** — The isolation is **autouse**: a test that requests no database
   fixture still gets it, so a future job-runner test inherits it without
   opting in and none of the six tests GGU-124 names is edited.
3. **AC-3** — `make test` passes **twice** in a row against one PostgreSQL
   with nothing wiped in between (both summaries pasted in the PR), and a row
   committed by one test is absent from the next.
4. **AC-4** — `cd backend && make gate` green.

## 7. Test plan

| AC | Unit test(s) | Integration test(s) |
|---|---|---|
| AC-1 | — (the helper needs a real database; its guard branch is pure and tested beside it) | `tests/integration/test_fixture_isolation.py::test_emptying_removes_committed_rows_from_every_migrated_table`, `::test_emptying_an_unmigrated_database_refuses_to_report_success` |
| AC-2 | — | `tests/integration/test_fixture_isolation.py::test_every_integration_test_requests_the_emptying_fixture` |
| AC-3 | — | `tests/integration/test_fixture_isolation.py::test_a_committed_row_outlives_the_test_that_wrote_it` + `::test_the_next_test_never_sees_the_previous_tests_committed_row`, and the two `make test` runs in the PR |
| AC-4 | the whole suite | the whole suite |

**Mutation checks required:** yes — not for auth, but because the thing being
fixed is a *fixture*, and `.claude/rules/backend/testing.md` says wiring gets a
mutation check. Changing `autouse=True` to `autouse=False` must turn the AC-2
test and the AC-3 pair red. Measured in the PR.

The AC-3 pair is **deliberately order-dependent**, against the general rule in
`.claude/rules/python/testing-integration.md` rule 3, and the exception is
narrow: the property under test *is* what one test leaves for the next, so
there is no way to observe it from inside a single test. Both halves carry the
reason in their docstrings, and neither uses a shared literal for anything but
that handoff.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Should `MIN_MIGRATED_TABLES` track the real count (8 today) instead of a floor of 4? | backend | Keep the floor. Its job is to catch *nothing reflected*; an exact count would be a second inventory of the schema and would fail on every migration that adds a table, which is the `test_component_names.py` cost without that file's payoff. |
| OD-2 | Should the suite also empty on session teardown, so a finished run leaves the database as it found it? | backend | No. It would make the "second run green" evidence in the PR pass even with a broken per-test fixture, which is the weaker claim looking like the stronger one. §3 records the trade. |
| OD-3 | Who adds the twice-in-a-row CI job? | whoever next owns `.github/` | The proposal in §9, with its `cmd` copied verbatim into `ship-gate.json` in the same commit. |

## 9. Rollout & observability

No flags, no migrations, no new metrics or log events — this ships as a test-only
change and is observable as the suite being runnable twice.

**The proposed CI half of AC-3**, for the branch that owns `.github/`: the
cheapest honest shape is a second step in `backend-ci`'s existing test job,
after the first `make test`, against the *same* `postgres:16` service
container:

```yaml
- name: Prove the suite leaves the database as it found it (pytest, second run)
  run: make test
  working-directory: backend
```

It costs one extra suite run on a warm environment and nothing else — no second
container, no second checkout. Under `.claude/rules/ci-conventions.md` §5 it
needs a `py.*` entry in `.claude/ship-gate.json` whose `cmd` is byte-identical
to whatever command that step runs, or `repo.gate-pairs` fails; if the runner
half is expressed as a distinct command rather than a repeat of `make test`,
the entry names that command instead. It belongs in `backend-ci` and not
`repo-ci` because its subject is one directory — §4b's test: `frontend/` is a
directory it does not apply to.

Note the asymmetry §5's third question would ask of it: a CI job can only ever
be seen *accepting* here, because the fixture it proves is already in the same
commit. The rejection is proven locally instead, and this PR pastes it — the
same shape as `frontend.verify-release-test`.
