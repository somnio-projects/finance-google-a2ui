"""Spec 0053 AC-5 — ``renderView`` re-renders without the model.

Every answer is validated against the vendored schemas, and the refusals are
asserted by code **and** by sentence, because the sentence is what a renderer
shows and the example file pins it.
"""

from typing import Any

import pytest

from app.core.principal import Principal
from app.presentation.a2ui_v1.wire import INVALID_FUNCTION_CALL, UNKNOWN_FUNCTION
from app.presentation.registry import REGISTRY
from app.schemas.a2ui_v1_events import CallAgentFunction
from app.services.a2ui_v1_payloads import PayloadRenderer
from app.services.a2ui_v1_render_view import (
    ACCEPTED_METRIC,
    BAD_ARGUMENTS,
    NOT_DEFINED,
    REJECTED_METRIC,
    UNKNOWN_VIEW,
    RenderViewService,
)
from tests.a2ui_v1_envelopes import example
from tests.a2ui_v1_schemas import errors
from tests.conftest import FakeReporter
from tests.unit.services.a2ui_v1_doubles import views


def _call(**overrides: Any) -> CallAgentFunction:
    """The example call, with ``callFunction`` members overridden."""
    message = example("call_agent_function.render_view.json")["data"][0]
    message["callAgentFunction"]["callFunction"].update(overrides)
    return CallAgentFunction.model_validate(message["callAgentFunction"])


def _args(**args: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "componentId": "root",
        "view": "portfolio.summary.v1",
        "options": {"range": "1y"},
    }
    return {"args": {**base, **args}}


async def _answer(
    principal: Principal, call: CallAgentFunction
) -> tuple[list[dict[str, Any]], FakeReporter]:
    reporter = FakeReporter()
    service = RenderViewService(
        registry=REGISTRY,
        payloads=PayloadRenderer(views=views(), principal=principal),
        reporter=reporter,
    )
    return await service.answer(call), reporter


async def test_render_view_answers_the_value_then_the_data_model(
    principal: Principal,
) -> None:
    messages, reporter = await _answer(principal, _call())

    assert errors("agent_to_renderer_list.json", messages) == []
    assert messages[0]["agentFunctionResponse"] == {
        "functionCallId": "call-01",
        "value": {"componentId": "root", "view": "portfolio.summary.v1"},
    }
    update = messages[1]["updateDataModel"]
    assert update["surfaceId"] == "turn-7f3a-0"
    assert update["path"] == "/root"
    assert update["value"]["options"] == {"range": "1y"}
    assert update["value"]["payload"]["change"]["period"] == "past year"
    assert reporter.metrics == [(ACCEPTED_METRIC, {"view": "portfolio.summary.v1"})]


async def test_the_answer_writes_to_the_component_it_names(
    principal: Principal,
) -> None:
    messages, _ = await _answer(principal, _call(**_args(componentId="payoff")))

    assert messages[1]["updateDataModel"]["path"] == "/payoff"


@pytest.mark.parametrize(
    ("overrides", "code", "sentence"),
    [
        ({"call": "deleteEverything"}, UNKNOWN_FUNCTION, NOT_DEFINED),
        (
            {"catalogId": "https://example.test/other.json"},
            UNKNOWN_FUNCTION,
            NOT_DEFINED,
        ),
        (
            {"args": {"view": "portfolio.summary.v1"}},
            INVALID_FUNCTION_CALL,
            BAD_ARGUMENTS,
        ),
        (_args(componentId="/root/../x"), INVALID_FUNCTION_CALL, BAD_ARGUMENTS),
        (_args(view="nothing.here.v1"), INVALID_FUNCTION_CALL, UNKNOWN_VIEW),
        (
            _args(options={"range": "5y"}),
            INVALID_FUNCTION_CALL,
            "Option 'range' must be one of: 1d, 1w, 1m, ytd, 1y, all.",
        ),
    ],
    ids=[
        "unknown-function",
        "foreign-catalog",
        "missing-arguments",
        "pointer-as-component-id",
        "unknown-view",
        "out-of-range-option",
    ],
)
async def test_a_refusal_is_one_error_response(
    principal: Principal, overrides: dict[str, Any], code: str, sentence: str
) -> None:
    messages, reporter = await _answer(principal, _call(**overrides))

    assert errors("agent_to_renderer_list.json", messages) == []
    assert messages == [
        {
            "version": "v1.0",
            "agentFunctionResponse": {
                "functionCallId": "call-01",
                "error": {"code": code, "message": sentence},
            },
        }
    ]
    assert reporter.metrics == [(REJECTED_METRIC, {"code": code})]
    assert "5y" not in str(reporter.metrics)
