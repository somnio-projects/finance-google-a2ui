"""Spec 0053 AC-6, AC-7 — every refusal is a JSON-RPC body, before any stream.

The table is the v0.9 refusal vocabulary (``a2a_dispatch``, ``a2a_actions``)
plus the one v1.0 adds: a renderer that does not declare the finance catalog.
None of them reaches the model.
"""

import pytest

from app.agent.contracts import ToolContext
from app.core.principal import Principal
from app.schemas.a2a import INVALID_PARAMS, METHOD_NOT_FOUND, UNSUPPORTED_OPERATION
from app.services.a2a_actions import ACTIONS_DISABLED
from app.services.a2a_dispatch import BAD_PARAMS, MALFORMED, UNKNOWN_METHOD
from app.services.a2ui_v1_dispatch import CATALOG_REQUIRED
from tests.a2ui_v1_envelopes import drill, envelope, prose
from tests.conftest import FakeFlags
from tests.unit.services.a2ui_v1_doubles import call_service

FOREIGN = {"a2uiRendererCapabilities": {"v1.0": {"supportedCatalogIds": ["x"]}}}


@pytest.mark.parametrize(
    ("body", "flags", "error"),
    [
        (None, None, {"code": INVALID_PARAMS, "message": MALFORMED}),
        (
            {**prose("x"), "method": "tasks/list"},
            None,
            {"code": METHOD_NOT_FOUND, "message": UNKNOWN_METHOD},
        ),
        (
            {**prose("x"), "method": "tasks/cancel"},
            None,
            {
                "code": UNSUPPORTED_OPERATION,
                "message": "tasks/cancel is not supported.",
            },
        ),
        (
            prose("x", metadata={}),
            None,
            {"code": INVALID_PARAMS, "message": CATALOG_REQUIRED},
        ),
        (
            prose("x", metadata=FOREIGN),
            None,
            {"code": INVALID_PARAMS, "message": CATALOG_REQUIRED},
        ),
        (
            envelope(
                {"kind": "data", "metadata": {"mimeType": "text/plain"}, "data": []}
            ),
            None,
            {"code": INVALID_PARAMS, "message": BAD_PARAMS},
        ),
        (
            drill(driver={"path": "/x"}),
            None,
            {"code": INVALID_PARAMS, "message": BAD_PARAMS},
        ),
        (drill(driver="NOPE"), None, None),
        (
            drill(),
            FakeFlags(enabled=False),
            {"code": METHOD_NOT_FOUND, "message": ACTIONS_DISABLED},
        ),
    ],
    ids=[
        "not-json",
        "unknown-method",
        "cancel",
        "no-capabilities",
        "foreign-catalog",
        "not-an-a2ui-part",
        "nested-context",
        "undeclared-driver",
        "actions-off",
    ],
)
async def test_a_refused_call_is_a_json_rpc_error_before_any_stream(
    principal: Principal,
    tool_context: ToolContext,
    body: object,
    flags: FakeFlags | None,
    error: dict[str, object] | None,
) -> None:
    outcome, model = await call_service(principal, tool_context, body, flags=flags)

    assert isinstance(outcome, dict)
    assert outcome["error"]["code"] == (error or {"code": INVALID_PARAMS})["code"]
    if error is not None:
        assert outcome["error"] == error
    assert model.calls == []
