"""The buttons the ticket draws, and whether any of them does anything (spec 0050).

**Not** ``actions``, and the name is load-bearing. A payload field called
``actions`` is read by ``contract.py`` and ``catalog_json.py`` as the
``SurfaceActionRef`` list — *what this surface may send back* — and rendered
into the catalog's actions table. This ticket sends nothing back: it has one
``effect``, ``recalculate``, and no endpoint, callback or submit (spec 0018
OD-2). A button that is drawn and does not fire is a different claim, so it
gets a different word.

It exists because the label was in the client. ``Review order`` and ``Save as
draft`` were Dart constants in ``order_ticket_v2_buttons.dart`` — design's copy,
compiled into the bundle, unable to follow the ``locale`` option, which is N-9
with the sentence pointing the other way. Serving the label fixes that without
promising anything: ``enabled`` is false and ``reason`` says why, in words the
client shows rather than invents.

**Only ``review`` is served.** ``Save as draft`` was the second placeholder and
the redesign's frame draws no second action; a control with no contract behind
it and no design asking for it is one nobody decided about (spec 0050 OD-3).
"""

from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

#: Where the button sits in the design's hierarchy. The client picks a style
#: from this; it never picks one from the label.
ControlKind = Literal["primary", "secondary"]

#: Why nothing on this card is live. The same fact the disclosure states, said
#: to the one control that would otherwise look like it disagreed.
NO_BROKER: Final[str] = (
    "This showcase has no broker: nothing is ever sent, placed or settled."
)


class TicketControl(BaseModel):
    """One button the design draws, with whether it is live and why not."""

    model_config = ConfigDict(frozen=True)

    key: str = Field(
        max_length=24,
        description="Stable id the client keys a widget off.",
        examples=["review"],
    )
    label: str = Field(
        max_length=48,
        description="What the button says, written here so no client spells it.",
        examples=["Review order"],
    )
    kind: ControlKind = Field(
        description="Its place in the design's hierarchy.", examples=["primary"]
    )
    enabled: bool = Field(
        description=(
            "Whether pressing it does anything. False on this ticket, and "
            "read by the client through `ViewPayload.flag` — the contract's "
            "own reader for a fact that is a flag rather than a word."
        ),
        examples=[False],
    )
    reason: str | None = Field(
        default=None,
        max_length=160,
        description=("Why it is not live, in words the client shows; null when it is."),
        examples=[NO_BROKER],
    )


#: The ticket's whole control set: the design's primary action, drawn and
#: inert. The frame draws it enabled; until an order can be reviewed this is
#: the state the frame needs and does not yet have (spec 0050 OD-2).
CONTROLS: Final[tuple[TicketControl, ...]] = (
    TicketControl(
        key="review",
        label="Review order",
        kind="primary",
        enabled=False,
        reason=NO_BROKER,
    ),
)

#: The bound the payload declares — one more than is served, so a second
#: control is a change to this number rather than to the field.
MAX_CONTROLS: Final[int] = 4

__all__ = [
    "CONTROLS",
    "MAX_CONTROLS",
    "NO_BROKER",
    "ControlKind",
    "TicketControl",
]
