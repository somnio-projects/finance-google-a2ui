"""§3.4 — the descriptor a surface publishes is derived, never retyped.

``SurfaceActionRef`` carries a single ``arg``/``control``/``choices`` triple,
so an action with a different number of arguments would be advertised
incompletely. ``declared_action`` refuses that at import rather than
under-publishing at runtime — the honesty rule the diagrams and the compliance
corpus follow, applied to a descriptor.
"""

from typing import Literal

import pytest
from pydantic import Field

from app.actions.contracts import ActionArgs
from app.actions.declared import declared_action
from app.actions.spec import SurfaceActionSpec
from app.core.errors import ConfigurationError


class _NoArgs(ActionArgs):
    """An action that takes nothing."""


class _TwoArgs(ActionArgs):
    """An action that takes more than the descriptor can advertise."""

    first: Literal["a"] = Field(default="a", description="One.", examples=["a"])
    second: Literal["b"] = Field(default="b", description="Two.", examples=["b"])


class _TextArg(ActionArgs):
    """An action whose argument is bounded by a pattern rather than an enum."""

    slug: str = Field(
        default="one",
        pattern=r"^[a-z]{1,8}$",
        description="A bounded token.",
        examples=["two"],
    )


def _spec(args: type[ActionArgs]) -> SurfaceActionSpec:
    """Build a throwaway action over ``args`` without registering it."""
    return SurfaceActionSpec(
        id="probe.thing.v1", label="Probe", args=args, prompt=lambda _: "probe"
    )


@pytest.mark.parametrize("args", [_NoArgs, _TwoArgs], ids=["none", "two"])
def test_an_action_that_is_not_one_argument_cannot_be_published(
    args: type[ActionArgs],
) -> None:
    with pytest.raises(ConfigurationError, match="publishes exactly one"):
        declared_action(_spec(args))


def test_a_text_argument_publishes_the_pattern_it_enforces() -> None:
    ref = declared_action(_spec(_TextArg))

    assert (ref.control, ref.choices) == ("text", ())
    assert ref.pattern == r"^[a-z]{1,8}$"


def test_the_descriptor_carries_the_action_id_and_label() -> None:
    ref = declared_action(_spec(_TextArg))

    assert (ref.action, ref.label, ref.arg) == ("probe.thing.v1", "Probe", "slug")
