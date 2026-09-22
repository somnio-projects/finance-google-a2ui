"""The terminal message recommends its chips (spec 0029)."""

import json

from app.actions.suggestions import (
    DECLARED_KEYS,
    recommended,
    suggestion_label,
    suggestion_prompt,
)
from app.agent.contracts import ToolContext
from app.core.model import ModelReply
from app.infra.model.null_client import NullModelClient
from app.schemas.a2a import ClientMessage
from app.services.a2a_service import A2aService
from tests.unit.services.test_a2a_service import ANSWER, make_service


async def _events(
    service: A2aService, context: ToolContext, text: str
) -> list[dict[str, object]]:
    message = ClientMessage.model_validate(
        {"role": "user", "parts": [{"kind": "text", "text": text}]}
    )
    return [
        json.loads(chunk.removeprefix("data: ").strip())
        async for chunk in service.stream(
            message=message, prompt=message.text(), task_id="task-1", context=context
        )
    ]


async def test_the_terminal_message_recommends_the_chips_not_just_asked(
    tool_context: ToolContext,
) -> None:
    """Spec 0029 — every curated chip but the one this turn ran, with labels."""
    service, _ = make_service(NullModelClient([ModelReply(text=ANSWER)]))
    asked = suggestion_prompt("tax-lots")

    events = await _events(A2aService(agent=service), tool_context, asked)

    message = next(event for event in events if event["kind"] == "message")
    chips = message["suggestions"]
    assert isinstance(chips, list)
    assert chips == [
        {"key": key, "label": suggestion_label(key)} for key in recommended(asked)
    ]
    assert "tax-lots" not in [chip["key"] for chip in chips]
    assert len(chips) == len(DECLARED_KEYS) - 1
