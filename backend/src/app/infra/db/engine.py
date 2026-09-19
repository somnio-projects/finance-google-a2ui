"""Engine factory and the database readiness probe."""

import structlog
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

from app.core.config import Settings
from app.core.logging import get_logger

log: structlog.stdlib.BoundLogger = get_logger(__name__)


def create_engine(settings: Settings) -> AsyncEngine:
    """Create the process-wide async engine from settings.

    ``pool_pre_ping`` drops dead connections before use so a database
    restart never surfaces as a request failure.
    """
    return create_async_engine(
        settings.database_url_str,
        pool_size=settings.database_pool_size,
        pool_pre_ping=True,
        echo=settings.database_echo,
    )


class DatabaseReadinessProbe:
    """``ReadinessProbe`` that runs ``SELECT 1`` against PostgreSQL."""

    name = "database"

    def __init__(self, engine: AsyncEngine) -> None:
        """Bind the probe to ``engine``."""
        self._engine = engine

    async def check(self) -> bool:
        """Return True when a trivial query succeeds."""
        try:
            async with self._engine.connect() as connection:
                await connection.execute(text("SELECT 1"))
        except (SQLAlchemyError, OSError) as exc:
            log.warning("db_readiness_check_failed", error=type(exc).__name__)
            return False
        return True


__all__ = ["DatabaseReadinessProbe", "create_engine"]
