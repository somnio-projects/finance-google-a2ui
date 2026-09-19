"""Spec 0010 — the client message the protocol accepts, and the ones it does not."""

import pytest

from app.schemas.a2a import ClientMessage


def test_a_message_joins_its_text_parts() -> None:
    message = ClientMessage.model_validate(
        {
            "role": "user",
            "parts": [
                {"kind": "text", "text": "why did"},
                {"kind": "text", "text": "I move?"},
            ],
        }
    )

    assert message.text() == "why did I move?"


@pytest.mark.parametrize(
    "payload",
    [
        {"role": "user", "parts": []},
        {"role": "agent", "parts": [{"kind": "text", "text": "hi"}]},
    ],
    ids=["no_parts", "not_the_user"],
)
def test_a_message_the_protocol_does_not_allow_is_rejected(
    payload: dict[str, object],
) -> None:
    with pytest.raises(ValueError, match="validation error"):
        ClientMessage.model_validate(payload)
