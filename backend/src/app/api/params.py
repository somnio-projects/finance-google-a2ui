"""Documented parameters shared by more than one controller.

`.claude/rules/backend/api-design.md` §3: pagination parameters and the
session path parameter are declared once, with their description, example and
bound, instead of being retyped in every controller that accepts them. A
third consumer reuses these; it does not copy them.
"""

import uuid
from typing import Annotated

from fastapi import Path, Query

from app.schemas.pagination import MAX_CURSOR_LENGTH

#: Largest page a caller may ask for, on any paginated collection.
MAX_PAGE_SIZE = 100
#: Page size used when the caller does not ask for one.
DEFAULT_PAGE_SIZE = 20

LimitQuery = Annotated[
    int,
    Query(
        ge=1,
        le=MAX_PAGE_SIZE,
        description=(
            "How many items to return in this page (1-100). The response "
            "carries `next_cursor` when more remain."
        ),
        examples=[DEFAULT_PAGE_SIZE],
    ),
]

CursorQuery = Annotated[
    str | None,
    Query(
        max_length=MAX_CURSOR_LENGTH,
        description=(
            "Opaque cursor from the previous page's `next_cursor`. Omit it for "
            "the first page; a cursor this service did not issue is rejected "
            "with 422 rather than silently restarting the collection."
        ),
        examples=["MjAyNi0wOS0xOVQxMjo0MzozOSswMDowMHw5ZTEw"],
    ),
]

SessionIdPath = Annotated[
    uuid.UUID,
    Path(
        description=(
            "Identifier returned when the session was created. A session owned "
            "by another subject answers 404, exactly as an unknown one does."
        ),
        examples=["9e10c0de-2f4b-4c7a-9a1a-1f0d2f5b7c31"],
    ),
]

__all__ = [
    "DEFAULT_PAGE_SIZE",
    "MAX_PAGE_SIZE",
    "CursorQuery",
    "LimitQuery",
    "SessionIdPath",
]
