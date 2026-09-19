"""Errors the presentation layer raises (spec 0005 §3).

They subclass ``app.core.errors``, so the existing RFC 9457 handler renders
them without the controllers knowing anything about them.
"""

from app.core.errors import NotFoundError


class UnknownViewError(NotFoundError):
    """The requested projection id is not registered."""

    code = "portfolio/unknown-view"


__all__ = ["UnknownViewError"]
