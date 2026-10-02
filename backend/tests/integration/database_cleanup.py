"""Emptying the migrated tables between integration tests (spec 0047, GGU-124).

Emptying the tables, not rolling back a session. A rolled-back outer
transaction only reaches rows
written through the session the fixture handed out, and the DB-backed suite
writes through three other paths as well: the app's own engine behind
`integration_client`, a job's `session_scope` in `build_container`, and two
genuinely concurrent sessions in `test_portfolio_concurrency`. Emptying the
tables reaches all four because it asks the database what it holds rather than
which session put it there. Spec 0047 §3 carries the full comparison.

The table list is **reflected**, never enumerated here: a migration that adds a
table is covered the day it lands rather than the day somebody remembers this
file. `alembic_version` is migration bookkeeping, not test data, and stays.
"""

from sqlalchemy import MetaData, Table, text
from sqlalchemy.ext.asyncio import AsyncEngine

MIGRATION_BOOKKEEPING = "alembic_version"

# A row lock left open by a previous test's undisposed connection would
# otherwise hang `make test` with no output at all. Fail with PostgreSQL's own
# lock_timeout error naming the table instead: a stuck suite that says why.
LOCK_TIMEOUT_MS = 5_000

# Reflection finding almost nothing means the DSN points at an unmigrated (or
# wrong) database, and deleting from an empty list of tables would report
# success for the wrong reason — the anti-vacuity guard the repository already
# applies to its shell and spelling checks, applied to this one.
MIN_MIGRATED_TABLES = 4


async def empty_every_table(engine: AsyncEngine) -> frozenset[str]:
    """Delete every row of every migrated table and name the tables emptied.

    Args:
        engine: An engine bound to the migrated test database.

    Returns:
        The names of the tables that were emptied.

    Raises:
        AssertionError: When reflection finds fewer tables than a migrated
            database must have, so an empty run cannot pass as a clean one.
    """
    metadata = MetaData()
    async with engine.begin() as connection:
        await connection.execute(
            text(f"SET LOCAL lock_timeout = '{LOCK_TIMEOUT_MS}ms'")
        )
        await connection.run_sync(metadata.reflect)
        tables = emptiable_tables(metadata)
        # Reverse dependency order: a child row goes before the parent it
        # references, so DELETE needs no CASCADE and no deferred constraints.
        for table in reversed(tables):
            await connection.execute(table.delete())
    return frozenset(table.name for table in tables)


def emptiable_tables(metadata: MetaData) -> list[Table]:
    """Return the reflected tables holding test data, in dependency order.

    Args:
        metadata: Metadata already reflected from the test database.

    Returns:
        Every reflected table except migration bookkeeping, parents first.

    Raises:
        AssertionError: When the list is too short to be a migrated database.
    """
    tables = [
        table for table in metadata.sorted_tables if table.name != MIGRATION_BOOKKEEPING
    ]
    if len(tables) < MIN_MIGRATED_TABLES:
        raise AssertionError(
            f"reflected only {len(tables)} table(s) "
            f"({sorted(table.name for table in tables)}); "
            "the test database looks unmigrated, so emptying it proves nothing"
        )
    return tables


__all__ = [
    "MIGRATION_BOOKKEEPING",
    "MIN_MIGRATED_TABLES",
    "emptiable_tables",
    "empty_every_table",
]
