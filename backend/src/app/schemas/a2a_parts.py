"""The parts a client message may carry (spec 0022 §3.2, ADR-J D-7).

Until GGU-78 the envelope accepted exactly one kind, ``text``, so a surface
that wanted to say "go deeper on DOGE" had one option available to it: make up
a sentence and send it. That is the unbounded-string-the-backend-interprets
shape this project argues against, arriving through the front door because no
bounded alternative was offered.

The alternative is A2A's own ``DataPart``, carrying a **registered action id
and scalar arguments** — nothing else. Every bound below is deliberate:

* ``extra="forbid"`` on the data object, so ``action`` and ``args`` are the
  only keys that exist;
* ``args`` capped at :data:`MAX_ARGS` keys, each value a bounded string, an
  int, a bool or ``null`` — **no nested objects and no arrays**. The no-nesting
  rule is the load-bearing one: a nested object is where a path expression
  hides, and ADR-K D-3 forbids interpreting one. Every declared argument in the
  catalog is a scalar; an action that genuinely needs structure amends the
  spec's §3.2 table with its reason.

Split from ``a2a.py`` under the 150-line budget, the same way
``a2a_openapi`` was.
"""

from typing import Annotated, Final, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

from app.actions.registry import ACTION_ID_PATTERN

#: Upper bound on an action's argument count. No registered action declares
#: more than one; this stops an unbounded object reaching the args model.
MAX_ARGS: Final[int] = 8
#: Upper bound on one argument's string value.
MAX_ARG_LENGTH: Final[int] = 64
#: Upper bound on an argument's **name**. Bounded because a rejection may
#: mention it: an unbounded key is an unbounded error message, and an error
#: message longer than its own field is a 500 (the lesson ``a2a_dispatch``
#: records).
MAX_ARG_NAME: Final[int] = 32

ArgName = Annotated[str, StringConstraints(max_length=MAX_ARG_NAME)]

#: What one argument may be. A ``dict`` or a ``list`` matches nothing here and
#: is therefore a rejection, which is the whole point.
ArgValue = (
    bool | int | Annotated[str, StringConstraints(max_length=MAX_ARG_LENGTH)] | None
)


class ActionData(BaseModel):
    """The payload of a `data` part: an action id and its scalar arguments."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    action: str = Field(
        max_length=MAX_ARG_LENGTH,
        pattern=ACTION_ID_PATTERN,
        description="Registered action id the surface published.",
        examples=["drill.attribution.v1"],
    )
    args: dict[ArgName, ArgValue] = Field(
        default_factory=dict,
        max_length=MAX_ARGS,
        description=(
            "Scalar arguments, validated against the action's own bounded "
            "model. No nested objects, no arrays."
        ),
        examples=[{"driver": "XOM"}],
    )


class TextPart(BaseModel):
    """Prose the user typed."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    kind: Literal["text"] = Field(
        default="text", description="Part discriminator.", examples=["text"]
    )
    text: str = Field(
        max_length=4000,
        description="What the user typed.",
        examples=["why did I move?"],
    )


class DataPart(BaseModel):
    """An action a surface sends back, instead of a sentence about it."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    kind: Literal["data"] = Field(description="Part discriminator.", examples=["data"])
    data: ActionData = Field(
        description="The registered action and its validated-elsewhere arguments.",
        examples=[{"action": "drill.attribution.v1", "args": {"driver": "XOM"}}],
    )


#: One part of a client message. Left un-discriminated on purpose: ``kind``
#: has always been optional on a text part, and a ``Field(discriminator=...)``
#: would start requiring it — a breaking change to a shipped contract for no
#: gain, since the two members differ by a required field anyway.
MessagePart = TextPart | DataPart


__all__ = [
    "MAX_ARGS",
    "MAX_ARG_LENGTH",
    "MAX_ARG_NAME",
    "ActionData",
    "ArgName",
    "ArgValue",
    "DataPart",
    "MessagePart",
    "TextPart",
]
