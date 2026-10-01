"""Spec 0053 §5 — the v1.0 client message is bounded at the boundary.

The one-kind rule is spec 0022 AC-5 carried over: a surface sends a message
or a person types a sentence, never both. The capabilities are read without
trusting their shape: absent, or present for another version only, is the
same answer — no catalog declared.
"""

import pytest
from pydantic import ValidationError

from app.schemas.a2ui_v1_message import V1ClientMessage
from tests.a2ui_v1_envelopes import example


def _message(*parts: object, metadata: object = None) -> V1ClientMessage:
    body: dict[str, object] = {"role": "user", "parts": list(parts)}
    if metadata is not None:
        body["metadata"] = metadata
    return V1ClientMessage.model_validate(body)


def test_a_data_part_beside_prose_is_refused() -> None:
    with pytest.raises(ValidationError, match="carries nothing else"):
        _message(
            example("action.drill_attribution.json"), {"kind": "text", "text": "hi"}
        )


def test_two_data_parts_are_refused() -> None:
    part = example("action.drill_attribution.json")

    with pytest.raises(ValidationError, match="carries nothing else"):
        _message(part, part)


def test_a_data_part_carries_exactly_one_message() -> None:
    part = example("action.drill_attribution.json")
    part["data"] = part["data"] * 2

    with pytest.raises(ValidationError, match="at most 1 item"):
        _message(part)


def test_prose_is_joined_into_one_prompt_and_carries_no_message() -> None:
    message = _message({"kind": "text", "text": " what"}, {"text": "moved? "})

    assert message.text() == "what moved?"
    assert message.renderer_message() is None


@pytest.mark.parametrize(
    "metadata",
    [None, {}, {"a2uiRendererCapabilities": {"v0.9": {"supportedCatalogIds": []}}}],
    ids=["no-metadata", "no-capabilities", "other-version-only"],
)
def test_no_v1_capabilities_declare_no_catalog(metadata: object) -> None:
    message = _message({"kind": "text", "text": "hi"}, metadata=metadata)

    assert message.catalogs() == ()
