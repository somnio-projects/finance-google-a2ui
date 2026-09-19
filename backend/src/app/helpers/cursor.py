"""Opaque keyset cursors for paginated collections (spec 0004).

A cursor encodes the ``(created_at, id)`` of the last item a caller saw, which
is exactly the key the collection indexes are ordered by. It is base64url so
that callers treat it as a token rather than as an offset they may arithmetic
on, not to hide anything: it is not a secret and carries no authorisation —
every query it feeds is still scoped by the caller's subject.
"""

import base64
import uuid
from datetime import datetime

from app.core.errors import ValidationFailedError

#: Separates the timestamp from the id inside the decoded payload.
SEPARATOR = "|"


def encode_cursor(created_at: datetime, entity_id: uuid.UUID) -> str:
    """Return the cursor that resumes a collection after this row."""
    raw = f"{created_at.isoformat()}{SEPARATOR}{entity_id}"
    return base64.urlsafe_b64encode(raw.encode()).decode().rstrip("=")


def decode_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    """Return the ``(created_at, id)`` key encoded in ``cursor``.

    Args:
        cursor: Value received in the ``cursor`` query parameter.

    Returns:
        The keyset position the next page starts after.

    Raises:
        ValidationFailedError: When ``cursor`` is not a cursor this service
            issued. It is never treated as "no cursor": silently restarting
            the collection would hide the bug and repeat rows.
    """
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        moment, _, entity_id = (
            base64.urlsafe_b64decode(padded).decode().partition(SEPARATOR)
        )
        return datetime.fromisoformat(moment), uuid.UUID(entity_id)
    except ValueError as exc:
        # binascii.Error and UnicodeDecodeError are both ValueError subclasses.
        raise ValidationFailedError("cursor is not a valid pagination cursor") from exc


__all__ = ["SEPARATOR", "decode_cursor", "encode_cursor"]
