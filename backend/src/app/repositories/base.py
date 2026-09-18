"""Generic repository with the operations every aggregate needs.

Subclasses set ``model`` and add aggregate-specific queries. Infrastructure
exceptions are translated to ``AppError`` subclasses here so services stay
free of SQLAlchemy imports.
"""

import uuid
from collections.abc import Sequence
from typing import ClassVar

from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DependencyUnavailableError, NotFoundError
from app.models.base import Base, TimestampMixin


class BaseRepository[ModelT: TimestampMixin]:
    """CRUD primitives over one ORM ``model``."""

    model: ClassVar[type[Base]]

    def __init__(self, session: AsyncSession) -> None:
        """Bind the repository to the request's session."""
        self._session = session

    async def add(self, entity: ModelT) -> ModelT:
        """Persist ``entity`` and flush so generated values are populated."""
        try:
            self._session.add(entity)
            await self._session.flush()
        except SQLAlchemyError as exc:
            raise DependencyUnavailableError("database write failed") from exc
        return entity

    async def get(self, entity_id: uuid.UUID) -> ModelT:
        """Return the entity with ``entity_id`` or raise ``NotFoundError``."""
        try:
            entity = await self._session.get(self.model, entity_id)
        except SQLAlchemyError as exc:
            raise DependencyUnavailableError("database read failed") from exc
        if entity is None:
            raise NotFoundError(f"{self.model.__name__} {entity_id} not found")
        return entity  # pyright: ignore[reportReturnType]

    async def list_recent(self, *, limit: int) -> Sequence[ModelT]:
        """Return up to ``limit`` entities, newest first."""
        model = self.model
        statement = (
            select(model)
            .order_by(model.created_at.desc())  # pyright: ignore[reportAttributeAccessIssue]
            .limit(limit)
        )
        try:
            result = await self._session.execute(statement)
        except SQLAlchemyError as exc:
            raise DependencyUnavailableError("database read failed") from exc
        return result.scalars().all()  # pyright: ignore[reportReturnType]


__all__ = ["BaseRepository"]
