"""Build response DTOs from persisted rows.

A row that no longer fits its DTO means the stored data is corrupt or a
migration is missing — a dependency problem, not a caller error. Translating
``ValidationError`` here keeps pydantic exceptions inside the domain
hierarchy so the API answers a typed 503 instead of a generic 500.
"""

from pydantic import BaseModel, ValidationError

from app.core.errors import DependencyUnavailableError


def from_row[DtoT: BaseModel](dto: type[DtoT], row: object) -> DtoT:
    """Validate ``row`` (an ORM entity) into ``dto``.

    Raises:
        DependencyUnavailableError: When the row does not satisfy the DTO.
    """
    try:
        return dto.model_validate(row)
    except ValidationError as exc:
        raise DependencyUnavailableError("stored data failed validation") from exc


__all__ = ["from_row"]
