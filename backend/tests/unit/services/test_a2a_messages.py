"""Spec 0010 / 0022 — the client message the protocol accepts, and the rest.

GGU-78 gave the envelope a second part kind. The new rule is that a message
carries **one** action or prose, never both and never two actions: precedence
between them would be a rule nobody wrote down, and "what did the client
actually ask for?" must have exactly one answer (spec 0022 AC-5).
"""

import pytest

from app.schemas.a2a import ClientMessage

DRILL = "drill.attribution.v1"


def _data_part(action: str = DRILL) -> dict[str, object]:
    """Build one `data` part carrying a registered action."""
    return {"kind": "data", "data": {"action": action, "args": {"driver": "LINK"}}}


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


def test_a_message_carrying_one_action_exposes_it_and_no_text() -> None:
    message = ClientMessage.model_validate({"role": "user", "parts": [_data_part()]})

    action = message.action()
    assert action is not None
    assert (action.action, dict(action.args)) == (DRILL, {"driver": "LINK"})
    assert message.text() == ""


def test_a_message_of_prose_carries_no_action() -> None:
    message = ClientMessage.model_validate(
        {"role": "user", "parts": [{"kind": "text", "text": "hi"}]}
    )

    assert message.action() is None


@pytest.mark.parametrize(
    "parts",
    [
        [_data_part(), _data_part("ask.suggested.v1")],
        [_data_part(), {"kind": "text", "text": "and also this"}],
        [{"kind": "text", "text": "do this"}, _data_part()],
    ],
    ids=["two_actions", "action_then_text", "text_then_action"],
)
def test_a_message_mixing_or_repeating_actions_is_rejected(
    parts: list[dict[str, object]],
) -> None:
    """AC-5 — one action or prose; the envelope refuses anything ambiguous."""
    with pytest.raises(ValueError, match="validation error"):
        ClientMessage.model_validate({"role": "user", "parts": parts})
