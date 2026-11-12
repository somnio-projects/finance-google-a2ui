"""GGU-164 (spec 0057) — the JSON-RPC ``id`` is a string, a number or null.

Declared per branch: a length bound on the union reached the integer and made
pydantic raise ``TypeError`` — which no handler maps — instead of a
``ValidationError``.
"""

import pytest
from pydantic import ValidationError

from app.schemas.a2a import MAX_ID_LENGTH, MAX_SAFE_INT, JsonRpcRequest


def _validate(rpc_id: object) -> JsonRpcRequest:
    return JsonRpcRequest.model_validate(
        {"jsonrpc": "2.0", "id": rpc_id, "method": "m"}
    )


@pytest.mark.parametrize(
    "rpc_id",
    ["req-1", "x" * MAX_ID_LENGTH, 1, 0, -7, MAX_SAFE_INT, -MAX_SAFE_INT, None],
    ids=["string", "longest-string", "int", "zero", "negative", "max", "min", "null"],
)
def test_a_valid_id_is_kept_with_its_json_type(rpc_id: object) -> None:
    envelope = _validate(rpc_id)

    assert envelope.id == rpc_id
    assert type(envelope.id) is type(rpc_id)


def test_an_absent_id_is_null() -> None:
    envelope = JsonRpcRequest.model_validate({"jsonrpc": "2.0", "method": "m"})

    assert envelope.id is None


@pytest.mark.parametrize(
    "rpc_id",
    ["x" * (MAX_ID_LENGTH + 1), MAX_SAFE_INT + 1, -MAX_SAFE_INT - 1, True, 1.5, [], {}],
    ids=[
        "long-string",
        "int-too-big",
        "int-too-small",
        "bool",
        "float",
        "list",
        "dict",
    ],
)
def test_an_invalid_id_is_a_validation_error_never_a_type_error(
    rpc_id: object,
) -> None:
    with pytest.raises(ValidationError):
        _validate(rpc_id)
