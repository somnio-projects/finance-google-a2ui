"""What makes a surface *editable* without making a projection stateful.

A projection is a pure function of *(domain result, options)* returning a
payload; it never receives an event (ADR-K D-6), so an interactive component's
editability cannot live in ``render``. It lives in the **declaration**: the
ticket's editable parameters *are* its declared options (ADR-K D-3), and the
payload publishes one descriptor per editable option, so the widget knows which
field is an input and what it may hold. Editing is the caller sending that
option back and re-rendering the same view over the two paths ADR-K D-11
already has — no state, no event loop, no second mechanism (spec 0018 OD-1).

Every published bound is **read from the options model's own JSON schema**,
never typed beside it: an advertised bound and an enforced bound are two
declarations of one fact, and written twice they drift — the failure
`.claude/rules/backend/testing.md` records three times. Not in ``fragments.py``
yet: ADR-K D-16 promotes a primitive when a second consumer needs it.
"""

from collections.abc import Mapping
from typing import Any, Final, Literal

from pydantic import BaseModel, ConfigDict, Field

#: Controls published today; a numeric one is absent on purpose, and
#: ``MAX_CHOICES`` keeps a descriptor's own list bounded (spec 0018 OD-4). The
#: seeded reference set names 17 tickers, so the bound sits above that.
Control = Literal["choice", "text"]
MAX_CHOICES: Final[int] = 24


class TicketInput(BaseModel):
    """One editable option, published with the bound the backend enforces."""

    model_config = ConfigDict(frozen=True)

    option: str = Field(
        max_length=32,
        description="Declared option to send back to re-render this view.",
        examples=["side"],
    )
    label: str = Field(
        max_length=64, description="Human label for the field.", examples=["Side"]
    )
    control: Control = Field(description="How to offer it.", examples=["choice"])
    value: str = Field(
        max_length=32,
        description="Current value, ready to be sent back unchanged.",
        examples=["buy"],
    )
    choices: tuple[str, ...] = Field(
        default=(),
        max_length=MAX_CHOICES,
        description="Every accepted value, for a `choice`; empty otherwise.",
        examples=[["buy", "sell"]],
    )
    pattern: str | None = Field(
        default=None,
        max_length=64,
        description="Regular expression a `text` value must match; else absent.",
        examples=["^[0-9]{1,9}(\\.[0-9]{1,8})?$"],
    )
    hint: str | None = Field(
        default=None,
        max_length=64,
        description=(
            "What the field accepts, in words, for the reader. The `pattern` "
            "beside it is the machine's copy of the same fact and is not for "
            "display: a client that rendered it put `^[0-9]{1,9}(\\.[0-9]"
            "{1,8})?$` under a form field. Written here because N-5 forbids "
            "a client turning a regex into prose."
        ),
        examples=["Up to 8 decimal places"],
    )


def _descriptor(
    *, option: str, label: str, value: str, schema: Mapping[str, Any]
) -> TicketInput:
    """Describe one option from its own JSON schema, never from a second copy."""
    choice = "enum" in schema
    return TicketInput(
        option=option,
        label=label,
        control="choice" if choice else "text",
        value=value,
        choices=tuple(schema["enum"]) if choice else (),
        pattern=None if choice else schema["pattern"],
        hint=None if choice else schema.get("hint"),
    )


def declared_inputs(
    options: BaseModel, labels: Mapping[str, str]
) -> tuple[TicketInput, ...]:
    """Publish the editable options of ``options``, in ``labels`` order.

    Args:
        options: The validated options this render came from; its values are
            what the widget starts from.
        labels: Editable option names mapped to their labels. An option absent
            here is still declared and accepted — just not offered as a field.

    Returns:
        One descriptor per editable option, carrying the bound its own options
        model enforces when the value comes back.
    """
    properties = type(options).model_json_schema()["properties"]
    return tuple(
        _descriptor(
            option=name,
            label=label,
            value=str(getattr(options, name)),
            schema=properties[name],
        )
        for name, label in labels.items()
    )


__all__ = [
    "MAX_CHOICES",
    "Control",
    "TicketInput",
    "declared_inputs",
]
