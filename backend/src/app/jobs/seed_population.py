"""Who a seed run writes to when the operator named a population (spec 0045).

The third of the seam `seed_arguments.py` opened: that module decides **who was
asked for**, this one resolves **who exists**, and `seed_portfolios.py` writes.
Keeping the resolution here is also what lets it be tested against a fake
repository rather than a patched session.
"""

from collections.abc import Sequence

from app.repositories.user_repository import UserRepository


async def selected_owners(
    users: UserRepository, *, owners: Sequence[str], all_owners: bool
) -> list[str]:
    """Return the owners this run writes to: the argument list, or everyone.

    Args:
        users: Bound to the **same session** the writes will use, so the
            population cannot go stale between two connections.
        owners: Already-normalised ownership keys from the command line.
        all_owners: Read every admitted account instead of using ``owners``.

    Returns:
        The ownership keys to seed, in the order they will be written.

    Raises:
        DependencyUnavailableError: When the database cannot be reached.
    """
    if all_owners:
        return await users.list_admitted_emails()
    return list(owners)


__all__ = ["selected_owners"]
