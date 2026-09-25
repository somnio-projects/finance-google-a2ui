"""The DB-backed suite's isolation, asserted rather than assumed (spec 0047).

GGU-124: six integration tests committed rows and left them behind, so a second
`make test` against the same PostgreSQL failed — and one of the six was a
*concurrency* test, so the symptom read like a race. CI never saw it because
every run got a fresh service container: the isolation was a property of the
environment, and nothing in the suite asserted it.

These do. AC-1 is the helper over real committed rows and its refusal to report
success against an unmigrated database, AC-2 is the wiring
(the fixture is autouse, so the next job-runner test is covered the day it is
written rather than the day somebody remembers), and AC-3 is the pair below —
the only case here that reproduces GGU-124's own failure mode, a row surviving
its own test and being absent from the next one.
"""

import pytest
from sqlalchemy import MetaData
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.repositories.user_repository import UserRepository
from tests.integration.database_cleanup import (
    MIGRATION_BOOKKEEPING,
    MIN_MIGRATED_TABLES,
    emptiable_tables,
    empty_every_table,
)

pytestmark = pytest.mark.integration

# Deliberately a fixed literal, which the rest of the suite is right to avoid:
# the two tests at the bottom are a *pair*, and a per-test uuid would make the
# second one unable to look for what the first one wrote.
LEFTOVER = "ggu124-leftover@example.test"

# Step 1 of that pair sets this; step 2 refuses to pass without it. `-k`, `--lf`,
# reordering the two functions or inserting a third between them would otherwise
# leave step 2 green over a database nothing had polluted — a test that cannot be
# shown to reject, which is the defect class this repository keeps meeting.
_step_one_ran = False


async def _remember(session: AsyncSession, email: str) -> None:
    """Commit one account row, the way the job-runner tests do."""
    await UserRepository(session).upsert(
        email=email,
        display_name="Leftover",
        role="member",
        status="active",
        invited_by="ggu124",
    )
    await session.commit()


async def test_emptying_removes_committed_rows_from_every_migrated_table(
    engine: AsyncEngine, session: AsyncSession
) -> None:
    """AC-1: the helper reaches a row that is already committed.

    A session rollback could not: the commit has happened, and the row is
    visible to every other connection.
    """
    await _remember(session, "committed@example.test")
    assert await UserRepository(session).find_by_email("committed@example.test")

    emptied = await empty_every_table(engine)

    # Every migrated table, not a sample of it: asserting two names would pass
    # while the helper silently skipped the other six.
    async with engine.begin() as connection:
        reflected = MetaData()
        await connection.run_sync(reflected.reflect)
    assert emptied == {
        name for name in reflected.tables if name != MIGRATION_BOOKKEEPING
    }
    assert len(emptied) >= MIN_MIGRATED_TABLES
    assert await UserRepository(session).find_by_email("committed@example.test") is None


def test_emptying_an_unmigrated_database_refuses_to_report_success() -> None:
    """AC-1: the anti-vacuity guard rejects, so a no-op cannot pass as clean.

    Needs no database — reflection is the only thing that reads one, and this
    hands the helper what reflection would have produced against the wrong DSN.
    It still lives here, beside the helper it guards, at the cost of being
    marked `integration` and so not running under `make test-unit`.
    """
    with pytest.raises(AssertionError, match="looks unmigrated"):
        emptiable_tables(MetaData())


async def test_a_test_requesting_no_database_still_gets_the_emptying_fixture(
    request: pytest.FixtureRequest,
) -> None:
    """AC-2: the fix is the fixture layer, so it is autouse, not opt-in.

    This test asks for no database fixture at all and still has to have it, so
    the next job-runner test inherits the isolation without opting in. Drop the
    `autouse=True` and this goes red. It asserts *this* test's fixture closure
    rather than walking every collected item — autouse is a property of the
    `conftest.py` that covers the directory, so one arbitrary member of it
    witnesses the whole.
    """
    assert "_empty_database" in request.fixturenames


async def test_a_committed_row_outlives_the_test_that_wrote_it(
    session: AsyncSession,
) -> None:
    """AC-3, step 1 of 2: commit and do **not** clean up — GGU-124's six did.

    Paired with the next test, which must not see this row. The pair is read
    together and only means anything in order; step 2 names it and refuses to
    pass unless this ran.
    """
    global _step_one_ran

    await _remember(session, LEFTOVER)

    assert await UserRepository(session).find_by_email(LEFTOVER) is not None
    _step_one_ran = True


async def test_the_next_test_never_sees_the_previous_tests_committed_row(
    session: AsyncSession,
) -> None:
    """AC-3, step 2 of 2: the row step 1 left behind is gone.

    This is GGU-124 reproduced inside the suite. On an empty database it would
    pass for no reason, so it asserts that its own premise held first: without
    step 1 there was nothing to clean up, and a green result would mean nothing.
    """
    assert _step_one_ran, (
        "step 1 of this pair did not run, so nothing polluted the database and "
        "this test proves nothing — run the file, not one test from it"
    )

    assert await UserRepository(session).find_by_email(LEFTOVER) is None
