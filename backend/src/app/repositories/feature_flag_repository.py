"""Repository for ``FeatureFlag`` rows (keyed by ``key``, not by UUID)."""

from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DependencyUnavailableError
from app.models.feature_flag import FeatureFlag


class FeatureFlagRepository:
    """Read and upsert flags; translates SQLAlchemy errors at the boundary."""

    def __init__(self, session: AsyncSession) -> None:
        """Bind the repository to the request's session."""
        self._session = session

    async def get(self, key: str) -> FeatureFlag | None:
        """Return the flag row for ``key`` or ``None`` when absent."""
        try:
            return await self._session.get(FeatureFlag, key)
        except (SQLAlchemyError, OSError) as exc:
            # OSError: asyncpg raises it for a refused connection, unwrapped
            raise DependencyUnavailableError("database read failed") from exc

    async def list_all(self) -> Sequence[FeatureFlag]:
        """Return every flag ordered by key."""
        try:
            result = await self._session.execute(
                select(FeatureFlag).order_by(FeatureFlag.key)
            )
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database read failed") from exc
        return result.scalars().all()

    async def upsert(
        self, key: str, *, enabled: bool, description: str | None, updated_by: str
    ) -> FeatureFlag:
        """Create or update the flag and flush so timestamps are populated."""
        try:
            flag = await self._session.get(FeatureFlag, key)
            if flag is None:
                flag = FeatureFlag(key=key, enabled=enabled, updated_by=updated_by)
                self._session.add(flag)
            flag.enabled = enabled
            flag.updated_by = updated_by
            if description is not None:
                flag.description = description
            await self._session.flush()
            await self._session.refresh(flag)
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database write failed") from exc
        return flag


__all__ = ["FeatureFlagRepository"]
