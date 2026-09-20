"""The documented A2A stream must keep the shape the code actually emits.

`app/api/a2a_openapi.py` is the only description of this endpoint a client
author gets: the body is one JSON-RPC envelope for many methods and the answer
is a stream, so FastAPI derives no schema from the signature and the examples
*are* the contract.

Hand-written examples rot. These assert the documented events against the
builders in `app.services.a2a_events` — key by key, and in order — so a change
to an event shape that forgets the document fails here rather than reaching a
client that was written against fiction.

Values are deliberately not compared: the example elides ids (`"7b1e..."`) to
stay readable. Shape and order are what a client binds to.
"""

import json

from app.agent.contracts import RenderIntent
from app.api.a2a_openapi import REQUEST_EXAMPLE, RPC_ERROR_EXAMPLE, STREAM_EXAMPLE
from app.services.a2a_events import COMPLETED, WORKING, answer, status, surface

TASK, CONTEXT = "7b1e...", "c2f1..."
INTENT = RenderIntent(view="attribution.waterfall.v1", options={"window": "30d"})


def _documented_events() -> list[dict[str, object]]:
    """Parse the `data:` frames of the documented stream, in order."""
    return [
        json.loads(line.removeprefix("data: "))
        for line in STREAM_EXAMPLE.splitlines()
        if line.startswith("data: ")
    ]


def test_the_documented_stream_frames_are_well_formed_sse() -> None:
    """Every frame is `data: <json>` followed by a blank line."""
    assert STREAM_EXAMPLE.endswith("\n\n")
    assert len(_documented_events()) == 4


def _built_events() -> list[dict[str, object]]:
    """The same four events, straight from the builders the adapter uses."""
    return [
        status(TASK, CONTEXT, WORKING),
        surface(TASK, CONTEXT, 0, INTENT),
        answer(TASK, CONTEXT, "…", (INTENT,)),
        status(TASK, CONTEXT, COMPLETED),
    ]


def test_the_documented_stream_follows_the_order_the_adapter_emits() -> None:
    """The expected order is *derived from the builders*, never restated here.

    It was written as a literal list first, and that version could not fail:
    renaming `render-intent` in `a2a_events` left the suite green while the
    document went on describing an event the service no longer sends.
    """
    assert [event["kind"] for event in _documented_events()] == [
        event["kind"] for event in _built_events()
    ]


def test_every_documented_event_has_the_keys_its_builder_produces() -> None:
    for shown, real in zip(_documented_events(), _built_events(), strict=True):
        assert shown["kind"] == real["kind"], (
            f"documented event {shown['kind']!r} is not what a2a_events builds "
            f"at that position ({real['kind']!r})"
        )
        assert set(shown) == set(real), (
            f"the documented {shown['kind']!r} event does not match what "
            f"a2a_events builds: documented {sorted(shown)}, real {sorted(real)}"
        )


def test_the_documented_status_states_are_the_ones_the_module_defines() -> None:
    """`working` and `completed` are constants, not strings this test invents."""
    documented = _documented_events()

    assert documented[0]["status"] == {"state": WORKING}
    assert documented[-1]["status"] == {"state": COMPLETED}


def test_the_documented_working_status_is_not_final_and_the_last_one_is() -> None:
    """The flag a client uses to know the turn ended."""
    events = _documented_events()

    assert events[0]["final"] is False
    assert events[-1]["final"] is True


def test_the_documented_render_intent_matches_the_registered_view_shape() -> None:
    """`renderIntent` must be a real projection id with declared options."""
    shown = _documented_events()[1]["renderIntent"]

    assert shown == INTENT.model_dump(mode="json")


def test_the_terminal_message_repeats_every_surface() -> None:
    """A client may ignore the incremental events; this is what makes that safe."""
    events = _documented_events()
    incremental = [e["renderIntent"] for e in events if e["kind"] == "render-intent"]

    assert events[2]["renderIntents"] == incremental


def test_the_request_example_is_the_method_the_surface_implements() -> None:
    assert REQUEST_EXAMPLE["jsonrpc"] == "2.0"
    assert REQUEST_EXAMPLE["method"] == "message/stream"


def test_the_error_example_is_a_json_rpc_object_not_a_problem_document() -> None:
    """The one place a failure is not RFC 9457 (ADR-J D-3), shown as such."""
    assert set(RPC_ERROR_EXAMPLE) == {"jsonrpc", "id", "error"}
    assert set(RPC_ERROR_EXAMPLE["error"]) == {"code", "message"}
    assert "type" not in RPC_ERROR_EXAMPLE
