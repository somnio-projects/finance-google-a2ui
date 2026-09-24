"""The provisioning job against a real PostgreSQL (spec 0041 AC-1..AC-4).

Two claims are the database's and can only be checked here:
``uq_users_email`` deciding that one address is one row, and "leave what
exists alone" behaving the same after a commit as it does against a dict.

The last case runs the function the Cloud Run job actually calls, so the
`session_scope` around it — and the commit that scope owns — is what is under
test rather than the loop inside it.
"""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.bootstrap import build_container
from app.core.config import Settings
from app.jobs.provision_users import PROVISION_JOB, provision, provision_into
from app.repositories.user_repository import UserRepository

pytestmark = pytest.mark.integration

AUDIENCE = ["first@example.test", "second@example.test"]


async def test_one_run_provisions_a_whole_audience(session: AsyncSession) -> None:
    """AC-1: several addresses, one invocation, all active members."""
    repository = UserRepository(session)

    added, untouched = await provision_into(repository, emails=AUDIENCE)
    await session.commit()

    assert (added, untouched) == (2, 0)
    for email in AUDIENCE:
        row = await repository.find_by_email(email)
        assert row is not None
        assert (row.role, row.status, row.invited_by) == (
            "member",
            "active",
            PROVISION_JOB,
        )


async def test_a_revoked_account_survives_a_run(session: AsyncSession) -> None:
    """AC-2, and the one that matters: a run cannot readmit somebody removed."""
    repository = UserRepository(session)
    await repository.upsert(
        email="gone@example.test",
        display_name="Gone",
        role="member",
        status="revoked",
        invited_by="admin",
    )
    await session.commit()

    added, untouched = await provision_into(repository, emails=["gone@example.test"])
    await session.commit()

    row = await repository.find_by_email("gone@example.test")
    assert (added, untouched) == (0, 1)
    assert row is not None
    assert (row.status, row.invited_by) == ("revoked", "admin")


async def test_running_it_again_writes_nothing(session: AsyncSession) -> None:
    """AC-3: an overlapping list costs nothing, after a commit as before one."""
    repository = UserRepository(session)
    await provision_into(repository, emails=["again@example.test"])
    await session.commit()

    second = await provision_into(repository, emails=["again@example.test"])
    await session.commit()

    assert second == (0, 1)


async def test_the_job_provisions_end_to_end_through_its_own_session(
    integration_settings: Settings,
) -> None:
    """The entry point, not just its loop: it opens a session and commits."""
    container = build_container(integration_settings)
    emails = ["endtoend@example.test"]
    try:
        first = await provision(container, emails=emails)
        second = await provision(container, emails=emails)
    finally:
        await container.engine.dispose()

    assert (first, second) == ((1, 0), (0, 1))
