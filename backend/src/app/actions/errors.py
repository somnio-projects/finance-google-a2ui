"""Errors the actions package raises (spec 0022 §3.2).

They subclass ``app.core.errors``, so nothing here knows about HTTP or about
JSON-RPC: the A2A adapter maps them onto the two error shapes that already
exist, and no third one is introduced.
"""

from app.core.errors import NotFoundError


class UnknownActionError(NotFoundError):
    """The requested action id is not registered."""

    code = "surface/unknown-action"


__all__ = ["UnknownActionError"]
