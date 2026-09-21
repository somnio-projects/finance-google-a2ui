"""What a surface *declares* about an action it offers (spec 0022 §3.4).

The generalisation of ``presentation.tickets.declared_inputs``: a projection
that offers an action publishes a descriptor derived from the arguments
model's **own JSON schema**, never hand-written beside it. As in spec 0018 §5,
a published bound the backend does not enforce is client-side-only validation,
and two declarations of one fact drift the moment one of them moves.

An action declares **exactly one** argument. That is not a shortcut: the
published shape carries a single ``arg``/``control``/``choices`` triple, and
an action whose arguments do not fit it would be advertised incompletely —
so ``declared_action`` refuses it at import rather than under-publishing at
runtime. The day an action needs two, this descriptor grows a list and the
spec's §3.4 table grows with it.
"""

from collections.abc import Mapping
from typing import Any, Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.actions.contracts import SurfaceAction
from app.core.errors import ConfigurationError

#: Controls a declaration may publish; a free-text action does not exist yet.
Control = Literal["choice", "text"]
#: Keeps a descriptor's own list bounded, as ``TicketInput`` does.
MAX_CHOICES: Final[int] = 16


class SurfaceActionRef(BaseModel):
    """One action a surface offers, with the bound the backend enforces."""

    model_config = ConfigDict(frozen=True)

    action: str = Field(
        max_length=64,
        description="Registered action id to send back in a `data` part.",
        examples=["drill.attribution.v1"],
    )
    label: str = Field(
        max_length=64,
        description="Words the affordance shows.",
        examples=["Break this down"],
    )
    arg: str = Field(
        max_length=32,
        description="The single argument this action takes.",
        examples=["driver"],
    )
    control: Control = Field(
        description="How to offer the argument.", examples=["choice"]
    )
    choices: tuple[str, ...] = Field(
        default=(),
        max_length=MAX_CHOICES,
        description="Every accepted value, for a `choice`; empty otherwise.",
        examples=[["ADA", "BTC", "DOGE", "ETH"]],
    )
    pattern: str | None = Field(
        default=None,
        max_length=64,
        description="Regular expression a `text` value must match; else absent.",
        examples=[None],
    )


def _sole_argument(action: SurfaceAction) -> tuple[str, Mapping[str, Any]]:
    """Return the action's one argument and its schema, or refuse to publish."""
    properties: Mapping[str, Any] = action.args.model_json_schema().get(
        "properties", {}
    )
    if len(properties) != 1:
        msg = (
            f"action {action.id!r} declares {len(properties)} arguments; a "
            "SurfaceActionRef publishes exactly one (spec 0022 §3.4)"
        )
        raise ConfigurationError(msg)
    name, schema = next(iter(properties.items()))
    return name, schema


def declared_action(action: SurfaceAction) -> SurfaceActionRef:
    """Describe ``action`` from its own arguments schema (spec 0022 AC-6).

    Args:
        action: The registered action a projection offers.

    Returns:
        The descriptor the payload, the A2UI props, ``GET /v1/views`` and the
        frozen contract all publish — one derivation, four consumers.

    Raises:
        ConfigurationError: When the action does not declare exactly one
            argument, which this shape cannot advertise honestly.
    """
    name, schema = _sole_argument(action)
    choice = "enum" in schema
    return SurfaceActionRef(
        action=action.id,
        label=action.label,
        arg=name,
        control="choice" if choice else "text",
        choices=tuple(schema["enum"]) if choice else (),
        pattern=None if choice else schema.get("pattern"),
    )


__all__ = ["MAX_CHOICES", "Control", "SurfaceActionRef", "declared_action"]
