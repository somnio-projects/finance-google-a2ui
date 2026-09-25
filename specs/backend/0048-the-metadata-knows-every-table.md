# 0048 — The metadata knows every table

- **Area:** backend
- **Status:** In progress
- **Ticket:** GGU-127 · **Related specs / ADRs:** [`backend/0047`](0047-the-db-backed-suite-cleans-up-after-itself.md) §3 (which found it), [`backend/0020`](0020-portfolio-persistence.md), [`backend/0027`](0027-user-provisioning.md), `.claude/rules/ci-conventions.md` §5
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-25

## 1. Problem

`backend/src/app/models/__init__.py` opened with *"Import every model here so
Alembic's autogenerate sees the full metadata"* and imported five names.
`Portfolio`, `PortfolioLot`, `PortfolioTransaction` and `User` were absent, and
`backend/alembic/env.py` does `target_metadata = Base.metadata` on exactly that
object. Measured on `develop`:

```console
$ uv run python -c "from app.models import Base; import app.models; print(sorted(Base.metadata.tables))"
['audit_events', 'feature_flags', 'messages', 'sessions']
```

Four of eight. Autogenerate reads a table that exists in the database and not in
the metadata as **deleted**, so `alembic revision --autogenerate` proposed
dropping half the schema — measured, before any change:

```python
def upgrade() -> None:
    op.drop_index(op.f('ix_portfolios_owner_email'), table_name='portfolios')
    op.drop_table('portfolios')
    op.drop_index(op.f('ix_portfolio_lots_portfolio_id'), table_name='portfolio_lots')
    op.drop_table('portfolio_lots')
    op.drop_index(op.f('ix_portfolio_transactions_portfolio_id'), table_name='portfolio_transactions')
    op.drop_table('portfolio_transactions')
    op.drop_table('users')
```

Nobody had been bitten because every migration so far was hand-written. The
first person to use the documented, ordinary command gets a plausible-looking
revision that destroys every portfolio and every account, and on a `backend-cd`
run it executes against dev before traffic shifts.

This is the repository's recurring defect in its purest form: **a property
written in a docstring and enforced by nothing** — the same shape as
`infra.shell-lint`'s subject, the `symbols` bound, the `register(...)` whose
removal left the suite green, `repo.spelling`'s scope and the manual run that
named no commit. The file stated the invariant in its first line and broke it
four times.

## 2. Scope

**In:**

- The four missing imports, and `__all__` with them.
- The **second half of the same defect**, found by fixing the first: with the
  imports in place, autogenerate stopped proposing four `drop_table` calls and
  started proposing three `op.drop_column('…', 'updated_at')`. `portfolios`,
  `portfolio_lots` and `portfolio_transactions` carry `updated_at` in PostgreSQL
  (migration `0005`'s `_timestamps()` helper) and carried it in no model.
- `UpdatedAtMixin` in `models/base.py`: one declaration of the column, for the
  six tables that have it. Three models spelled it out identically and three
  omitted it.
- A test that compares what autogenerate sees against what the migrations built,
  holding both halves, and `docs/diagrams/07-data-model.md`, which was missing
  `updated_at` on two of those tables — the third stale declaration of one fact.

**Out:**

- Any migration. No table, column, index or revision changes; the database is
  already what the models now describe.
- Giving `updated_at` a database-side trigger. It is ORM-side (`onupdate`), as it
  already was on the other three tables.
- A gate entry. The property is one directory's, so it is a test, not a
  `repo.*` check (`ci-conventions.md` §5, second question).

## 3. Design

**AC-2 must not be a list of eight names.** A literal set in the test is the same
unenforced claim one level down: green until somebody adds a ninth model *and*
remembers to edit it. Both halves of the check therefore compare against the
schema Alembic actually created, read back by reflection, so a ninth table is
covered the day its migration lands.

**And it must not read `Base.metadata` in the test process.** This is the part
that is easy to get wrong and was measured rather than assumed. By the time
pytest has collected the suite, `app.models.portfolio` and `app.models.user`
have been imported by the repositories that use them, and the registry holds
every table *whatever* `models/__init__.py` says — with the `User` import
deleted:

```console
$ uv run python -c "import app.repositories.user_repository; from app.models import Base; print(sorted(Base.metadata.tables))"
['audit_events', 'feature_flags', 'messages', 'portfolio_lots', 'portfolio_transactions', 'portfolios', 'sessions', 'users']
```

An in-process assertion over `Base.metadata` is **green on the broken tree**.
The table set is therefore measured in a fresh interpreter that imports exactly
what `alembic/env.py` imports — the only process whose registry answers the
question that was asked.

The second test is in-process on purpose, and sound there for the opposite
reason: importing a module can only *add* a table, never add or drop a column,
so column drift is identical in either process. It asks alembic itself
(`compare_metadata`) for the diff and asserts it is empty, which makes AC-4 a
standing assertion rather than a paste that ages.

The anti-vacuity guard comes for free: the reflected list runs through
`emptiable_tables` (spec 0047), which refuses a database too small to be
migrated, so an equality of two empty sets cannot pass.

## 4. Data model & migration

**None.** No table, column, index or Alembic revision changes. The three
`updated_at` columns have existed since migration `0005`; this spec makes the
models say so. Existing rows are unaffected in every environment.

One runtime consequence, recorded because it is a behaviour change rather than a
description: the three portfolio tables' `updated_at` now carries SQLAlchemy's
`onupdate=func.now()`, as `sessions`, `feature_flags` and `users` already did, so
an ORM update of one of those rows bumps it. Nothing in `src/` or `tests/` reads
the column, so the blast radius is that one value. The alternative — declaring
the column without `onupdate` — was rejected: it would leave `models/` with two
spellings of one fact, which is what this spec is about.

## 5. Security notes

No route, token, scope, audit event or personal-data path changes. The risk this
closes is an availability and integrity one: a generated revision that drops
`users` and `portfolios` and would be applied by `backend-cd` against dev before
traffic shifts. Migrations remain the only schema path.

## 6. Acceptance criteria

1. **AC-1** — `app.models.Base.metadata.tables` contains all eight tables after
   `import app.models` alone.
2. **AC-2** — A test asserts that the metadata's table set equals the set Alembic
   has migrated, read from the database, with no hard-coded list of names, so a
   ninth model added without its import fails the gate.
3. **AC-3** — The check is shown to reject: one import removed, red naming the
   missing table; restored, green. Both outputs in the PR.
4. **AC-4** — `alembic revision --autogenerate` against an up-to-date database
   produces an **empty** revision, pasted in the PR, and the suite asserts the
   same property so it cannot quietly stop being true.
5. **AC-5** — `cd backend && make gate` green.

## 7. Test plan

| AC | Unit test(s) | Integration test(s) |
|---|---|---|
| AC-1, AC-2 | — | `tests/integration/test_metadata_completeness.py::test_the_metadata_autogenerate_reads_holds_every_migrated_table` |
| AC-4 | — | `tests/integration/test_metadata_completeness.py::test_autogenerating_against_the_migrated_schema_finds_nothing_to_change` |

Both need the migrated database, so both are integration tests; neither is a
unit test with a double, because the whole point is to compare against a schema
this repository did not write down twice.

Mutation checks required: **yes** — both tests, in the PR body. Removing the
`User` import must fail naming `users`; removing `UpdatedAtMixin` from
`Portfolio` must fail naming `portfolios.updated_at`.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Should the table check become a `repo.*` gate entry so it runs without a database? | TL | No — its subject is one directory, so it stays a test inside `py.test` (`ci-conventions.md` §5). Reflection needs the database that `make gate` already starts. |
| OD-2 | Should `models/__init__.py` import its package's modules by walking the directory instead of naming them? | TL | No — an explicit import list is the public surface `__all__` documents, and a walk would hide a typo'd module name. The test is what makes the list honest. |

## 9. Rollout & observability

No flag, no migration, no metric. The change is visible in one place: the next
`alembic revision --autogenerate` writes an empty revision instead of a
destructive one, and the integration suite fails if that stops being true.
