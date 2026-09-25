"""Who ``--all`` actually reaches, against a real PostgreSQL (spec 0045).

One claim can only be checked here, and it is the one that decides whether a
run is safe: the population is the **admitted** accounts and nothing else. A
`revoked` row inside it would undo an offboarding somebody performed, and a
`requested` row would hand a portfolio dated today to a person who has not
been let in yet — both silently, because the job reports counts and never
addresses.
"""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.jobs.seed_population import selected_owners
from app.repositories.user_repository import UserRepository

pytestmark = pytest.mark.integration

#: One account per status the registry can hold, so the filter is asserted
#: against the whole enumeration rather than against the two we expect.
POPULATION: dict[str, str] = {
    "active": "active@population.test",
    "invited": "invited@population.test",
    "requested": "requested@population.test",
    "revoked": "revoked@population.test",
}


async def _register(session: AsyncSession) -> UserRepository:
    """Put one account of every status in the registry."""
    users = UserRepository(session)
    for status, email in POPULATION.items():
        await users.upsert(
            email=email,
            display_name=None,
            role="member",
            status=status,
            invited_by=None,
        )
    await session.commit()
    return users


async def test_selected_owners_reaches_the_admitted_accounts_only(
    session: AsyncSession,
) -> None:
    users = await _register(session)

    chosen = await selected_owners(users, owners=[], all_owners=True)

    # Asserted over *this* population rather than over the whole table: the
    # registry is shared with every other integration test, and a test that
    # needs the database empty is a test that fails for somebody else's
    # reason (GGU-124). The claim here is the filter, and the filter is a
    # property of these four rows.
    assert POPULATION["active"] in chosen
    assert POPULATION["invited"] in chosen
    # Both named, so a future status cannot quietly join the population — and
    # the two lines above are what stop these from passing on an empty answer.
    assert POPULATION["revoked"] not in chosen
    assert POPULATION["requested"] not in chosen


async def test_selected_owners_returns_the_named_list_untouched_by_the_registry(
    session: AsyncSession,
) -> None:
    await _register(session)
    users = UserRepository(session)

    chosen = await selected_owners(
        users, owners=["stranger@elsewhere.test"], all_owners=False
    )

    assert chosen == ["stranger@elsewhere.test"]
