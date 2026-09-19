import uuid
from datetime import UTC, datetime

import pytest

from app.core.errors import ValidationFailedError
from app.helpers.cursor import SEPARATOR, decode_cursor, encode_cursor


def test_encode_then_decode_round_trips_the_keyset_position() -> None:
    moment = datetime(2026, 9, 19, 12, 43, 39, 42545, tzinfo=UTC)
    entity_id = uuid.uuid4()
    decoded = decode_cursor(encode_cursor(moment, entity_id))
    assert decoded == (moment, entity_id)


def test_encoded_cursor_is_url_safe_and_unpadded() -> None:
    cursor = encode_cursor(datetime(2026, 9, 19, tzinfo=UTC), uuid.uuid4())
    assert "=" not in cursor
    assert "+" not in cursor
    assert "/" not in cursor
    assert SEPARATOR not in cursor


@pytest.mark.parametrize(
    "cursor",
    ["not-base64!!", "", "Zm9vfGJhcg", "MjAyNi0wOS0xOVQxMjowMDowMCswMDowMA"],
    ids=["not_base64", "empty", "decodes_but_not_a_key", "timestamp_without_id"],
)
def test_decode_rejects_a_garbled_cursor(cursor: str) -> None:
    with pytest.raises(ValidationFailedError, match="not a valid pagination cursor"):
        decode_cursor(cursor)
