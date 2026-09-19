"""Request-scoped session lifecycle (unit of work).

One session per request: commit on success, rollback on any exception,
always closed. Repositories receive the session; they never open one.
"""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
)


def create_session_factory(engine: AsyncEngine) -> async_sessionmaker[AsyncSession]:
    """Return a configured ``async_sessionmaker`` bound to ``engine``."""
    return async_sessionmaker(engine, expire_on_commit=False, autoflush=False)


@asynccontextmanager
async def session_scope(
    factory: async_sessionmaker[AsyncSession],
) -> AsyncGenerator[AsyncSession]:
    """Yield a session and finish the unit of work.

    Commits when the body completes, rolls back and re-raises otherwise.
    """
    session = factory()
    try:
        yield session
        await session.commit()
    except BaseException:
        # BaseException on purpose: CancelledError/KeyboardInterrupt must roll back too.
        await session.rollback()
        raise
    finally:
        await session.close()


__all__ = ["create_session_factory", "session_scope"]
