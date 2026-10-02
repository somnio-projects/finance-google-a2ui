"""The declared text search two tabs share (spec 0035 §3.3, ADR-K D-3).

A search is an **option**, not a client behaviour: the rows a list shows are
the rows the server sent, in the order it sent them (N-10). So the needle
arrives as a bounded field on the projection's own options model and the
matching happens here, once, for every projection that composes the mixin.

Two properties are worth naming because they are choices:

* **It matches domain fields, never rendered ones** (OD-6). A caption is a
  string this layer just wrote; matching against it would make a search
  result change when a label is reworded, and would make the same query
  answer differently per `locale`.
* **A blank needle is no filter at all**, not a filter that matches nothing.
  A text field that has been focused and emptied must show the list again.
"""

from typing import Final

from pydantic import Field

from app.presentation.options import ProjectionOptions

#: Long enough for a ticker, a fund name or a memo fragment; short enough
#: that the bound is obviously not a place to put a payload.
MAX_QUERY: Final[int] = 24


class SearchOptions(ProjectionOptions):
    """A free-text needle, bounded, matched as a case-insensitive substring."""

    query: str | None = Field(
        default=None,
        max_length=MAX_QUERY,
        description=(
            "Narrow the rows to those whose symbol or description contains "
            "this text, case-insensitively. Blank or omitted is no filter."
        ),
        examples=["btc"],
    )

    @property
    def needle(self) -> str:
        """The query folded for comparison; empty string when unfiltered."""
        return (self.query or "").strip().casefold()


def matches(needle: str, *fields: str | None) -> bool:
    """Return whether any of ``fields`` contains ``needle``.

    Args:
        needle: An already-folded, already-stripped query; empty means *keep*.
        fields: The domain values to look in; ``None`` is treated as absent.

    Returns:
        True when there is nothing to filter by, or when one field contains it.
    """
    if not needle:
        return True
    return any(needle in (field or "").casefold() for field in fields)


__all__ = ["MAX_QUERY", "SearchOptions", "matches"]
