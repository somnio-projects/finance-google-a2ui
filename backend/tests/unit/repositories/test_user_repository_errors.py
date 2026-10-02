"""What the user repository does when the database refuses (spec 0045).

Error paths, and only error paths — the branches a working database never
takes, which is exactly why they would otherwise ship unexercised. The rule
they enforce is the one `test_portfolio_repository_errors.py` states: **a
driver exception never escapes the repository**, because nothing upstream
imports SQLAlchemy and so nothing upstream could name it.

It matters more than usual for `list_admitted_emails`. Its caller is the seed
job's ``--all``, whose whole claim is *every admitted account*; a read that
failed halfway and returned what it had would seed a subset and report
success, which is the failure mode this repository keeps finding.
"""

import pytest
from sqlalchemy.exc import OperationalError

from app.core.errors import DependencyUnavailableError
from app.repositories.user_repository import UserRepository

LOST_CONNECTION = OperationalError("SELECT 1", {}, Exception("connection lost"))


class BrokenSession:
    """A session whose every statement fails the way a lost database does."""

    async def execute(self, *_: object, **_kwargs: object) -> object:
        """Fail the way a dropped connection does."""
        raise LOST_CONNECTION


async def test_list_admitted_emails_reports_the_database_rather_than_the_driver() -> (
    None
):
    repository = UserRepository(BrokenSession())  # pyright: ignore[reportArgumentType]

    with pytest.raises(DependencyUnavailableError, match="database read failed"):
        await repository.list_admitted_emails()
