"""What a v1.0 renderer may send back inside a ``DataPart`` (ADR-M D-6, D-7).

Only the two renderer-to-agent messages this agent answers are modelled:
``callAgentFunction`` (an edit, answered without the model) and ``action`` (a
new turn). A renderer's ``error`` report and ``rendererFunctionResponse`` are
not modelled, because this agent sends nothing that would provoke them, and a
message this service ignores is better refused than half-read.

Every field is bounded. ``action.context`` reuses the v0.9 action arguments'
scalar-only type: a nested object is where a path expression hides, and the
renderer resolves bindings before it sends, so nothing structured is owed.
"""

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.a2a_parts import MAX_ARGS, ArgName, ArgValue

#: Upper bound on a function call's arguments. ``renderView`` takes three.
MAX_FUNCTION_ARGS = 8
#: The ids a renderer echoes back; bounded because a response repeats them.
MAX_ID = 128


class ActionEvent(BaseModel):
    """A user action on a surface, reported by the renderer (ADR-M D-7)."""

    model_config = ConfigDict(frozen=True, extra="ignore", populate_by_name=True)

    name: str = Field(
        pattern=r"^[A-Za-z_][A-Za-z0-9_]{0,63}$",
        description="The action's v1.0 name, a UAX #31 identifier.",
        examples=["drill_attribution"],
    )
    surface_id: str = Field(
        alias="surfaceId",
        max_length=MAX_ID,
        description="The surface the action came from.",
        examples=["turn-4b10-0"],
    )
    source_component_id: str = Field(
        alias="sourceComponentId",
        max_length=64,
        description="The component that raised it.",
        examples=["root"],
    )
    timestamp: str = Field(max_length=64, description="ISO 8601, as sent.")
    context: dict[ArgName, ArgValue] = Field(
        max_length=MAX_ARGS,
        description="Resolved scalar arguments, validated by the action's model.",
        examples=[{"driver": "LINK"}],
    )


class FunctionCallIn(BaseModel):
    """The ``callFunction`` of a ``callAgentFunction``: a name and arguments."""

    model_config = ConfigDict(frozen=True, extra="forbid", populate_by_name=True)

    call: str = Field(
        max_length=64, description="Function name.", examples=["renderView"]
    )
    catalog_id: str | None = Field(
        default=None,
        alias="catalogId",
        max_length=256,
        description="The catalog the function belongs to; the surface's when absent.",
    )
    args: dict[str, Any] = Field(
        default_factory=dict,
        max_length=MAX_FUNCTION_ARGS,
        description="Arguments; the function's own model validates them.",
    )


class CallAgentFunction(BaseModel):
    """A renderer asking the agent to run a catalog function (ADR-M D-6)."""

    model_config = ConfigDict(frozen=True, extra="forbid", populate_by_name=True)

    surface_id: str = Field(
        alias="surfaceId",
        max_length=MAX_ID,
        description="The surface whose component is re-rendered.",
        examples=["turn-7f3a-0"],
    )
    function_call_id: str = Field(
        alias="functionCallId",
        max_length=MAX_ID,
        description="Copied into the response, for correlation.",
        examples=["call-01"],
    )
    call_function: FunctionCallIn = Field(
        alias="callFunction", description="The function and its arguments."
    )


class ActionMessage(BaseModel):
    """A v1.0 ``action`` message: a user did something on a surface."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    version: Literal["v1.0"] = Field(description="Always `v1.0`.")
    action: ActionEvent = Field(description="The action and its context.")


class FunctionMessage(BaseModel):
    """A v1.0 ``callAgentFunction`` message: a renderer asks for a function."""

    model_config = ConfigDict(frozen=True, extra="forbid", populate_by_name=True)

    version: Literal["v1.0"] = Field(description="Always `v1.0`.")
    call_agent_function: CallAgentFunction = Field(
        alias="callAgentFunction", description="The function call."
    )


#: One renderer-to-agent message this agent answers. ``extra="forbid"`` on
#: both members is what makes a message carrying both kinds, or neither, match
#: nothing — a rejection rather than a precedence rule.
RendererMessage = ActionMessage | FunctionMessage


__all__ = [
    "MAX_FUNCTION_ARGS",
    "ActionEvent",
    "ActionMessage",
    "CallAgentFunction",
    "FunctionCallIn",
    "FunctionMessage",
    "RendererMessage",
]
