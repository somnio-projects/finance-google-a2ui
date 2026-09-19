"""The pagination envelope every paginated collection answers with (spec 0004).

Keyset pagination, not offset: ``next_cursor`` is an opaque token built from
the last item of the page (``app.helpers.cursor``), so a page never repeats or
skips a row while the collection grows underneath the caller. It exists once,
here, and concrete pages subclass it — ``.claude/rules/backend/api-design.md``
§3 (repeated response shapes live in one place).
"""

from pydantic import BaseModel, ConfigDict, Field

#: Upper bound on an encoded cursor, mirrored by the ``cursor`` query parameter.
MAX_CURSOR_LENGTH = 128


class Page[ItemT](BaseModel):
    """One page of a collection plus the cursor that continues it."""

    model_config = ConfigDict(frozen=True)

    items: list[ItemT] = Field(
        description="The rows of this page, in the order documented by the route.",
    )
    next_cursor: str | None = Field(
        default=None,
        max_length=MAX_CURSOR_LENGTH,
        description=(
            "Opaque cursor to pass as `?cursor=` for the next page; `null` when "
            "this is the last page. Treat it as a token, not as a position."
        ),
        examples=["MjAyNi0wOS0xOVQxMjo0MzozOSswMDowMHw5ZTEw"],
    )


__all__ = ["MAX_CURSOR_LENGTH", "Page"]
