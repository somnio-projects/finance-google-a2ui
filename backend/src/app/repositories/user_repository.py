"""Repository for ``User`` rows (spec 0027), keyed by lower-cased e-mail."""

from collections.abc import Sequence
from datetime import datetime
from typing import Final

from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DependencyUnavailableError
from app.models.user import User

#: The statuses an account must be in for a seeded portfolio to mean anything.
#:
#: ``revoked`` is absent for the reason ``provision_users`` states out loud: an
#: offboarding somebody performed is not undone by a job run. ``requested`` is
#: absent for a subtler one — that account cannot sign in yet, so seeding it now
#: would fix an ``as_of`` at today and the lazy provider would never replace it,
#: handing the person a portfolio dated before they were admitted.
ADMITTED: Final[tuple[str, ...]] = ("active", "invited")


class UserRepository:
    """Read and write provisioned accounts; translates SQLAlchemy errors."""

    def __init__(self, session: AsyncSession) -> None:
        """Bind the repository to the request's session."""
        self._session = session

    async def find_by_email(self, email: str) -> User | None:
        """Return the account for ``email`` (already lower-cased) or ``None``."""
        try:
            result = await self._session.execute(
                select(User).where(User.email == email)
            )
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database read failed") from exc
        return result.scalar_one_or_none()

    async def list_all(self, *, limit: int) -> Sequence[User]:
        """Return up to ``limit`` accounts, newest first."""
        try:
            result = await self._session.execute(
                select(User).order_by(User.created_at.desc(), User.email).limit(limit)
            )
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database read failed") from exc
        return result.scalars().all()

    async def list_admitted_emails(self) -> list[str]:
        """Return the ownership key of every admitted account, oldest first.

        Deliberately unbounded, unlike :meth:`list_all`. Its caller is the seed
        job's ``--all``, whose whole claim is *every* account — a limit there
        would seed a subset and report success, which is the failure this
        repository's rules keep finding. The population is a demo audience,
        counted in tens.

        Returns:
            Lower-cased addresses of the ``active`` and ``invited`` accounts.

        Raises:
            DependencyUnavailableError: When the database cannot be reached.
        """
        try:
            result = await self._session.execute(
                select(User.email)
                .where(User.status.in_(ADMITTED))
                .order_by(User.created_at, User.email)
            )
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database read failed") from exc
        return list(result.scalars().all())

    async def upsert(
        self,
        *,
        email: str,
        display_name: str | None,
        role: str,
        status: str,
        invited_by: str | None,
    ) -> User:
        """Create the account or move an existing one to the given state."""
        try:
            row = await self.find_by_email(email)
            if row is None:
                row = User(email=email, role=role, status=status)
                self._session.add(row)
            row.role = role
            row.status = status
            row.invited_by = invited_by
            if display_name is not None:
                row.display_name = display_name
            await self._session.flush()
            await self._session.refresh(row)
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database write failed") from exc
        return row

    async def touch(
        self, row: User, *, seen_at: datetime, status: str | None = None
    ) -> User:
        """Record a sign-in, moving the status when the caller says so."""
        try:
            row.last_seen_at = seen_at
            if status is not None:
                row.status = status
            await self._session.flush()
            await self._session.refresh(row)
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database write failed") from exc
        return row


__all__ = ["UserRepository"]
