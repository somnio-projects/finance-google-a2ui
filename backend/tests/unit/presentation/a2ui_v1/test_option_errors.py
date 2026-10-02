"""ADR-M D-6 — the one sentence a refused ``renderView`` answers with.

The registry's own projection is used where it exercises the branch (the
example file's ``range`` refusal is the real summary options model); a small
stand-in covers the schema shapes no shipped projection happens to have —
an enum behind a ``$ref``, a nullable choice, a cross-option rule.
"""

from dataclasses import dataclass
from enum import StrEnum
from typing import Literal, Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.presentation.a2ui_v1.option_errors import options_rejection
from app.presentation.registry import REGISTRY

SUMMARY = REGISTRY.get("portfolio.summary.v1")


class Shade(StrEnum):
    """A closed set the JSON schema publishes under ``$defs``."""

    LIGHT = "light"
    DARK = "dark"


class StandInOptions(BaseModel):
    """Options shaped to reach every branch of the sentence builder."""

    model_config = ConfigDict(extra="forbid")

    shade: Shade = Shade.LIGHT
    side: Literal["buy", "sell"] | None = None
    low: int = Field(default=0, ge=0, le=10)
    high: int = Field(default=10, ge=0, le=10)

    @model_validator(mode="after")
    def _ordered(self) -> Self:
        if self.low > self.high:
            msg = "low above high"
            raise ValueError(msg)
        return self


@dataclass(frozen=True)
class StandIn:
    """The two attributes the judge reads off a projection."""

    id: str = "stand.in.v1"
    options: type[BaseModel] = StandInOptions


def test_accepted_options_are_not_refused() -> None:
    assert options_rejection(SUMMARY, {"range": "1y"}) is None


def test_a_closed_choice_names_the_declared_values() -> None:
    assert options_rejection(SUMMARY, {"range": "5y"}) == (
        "Option 'range' must be one of: 1d, 1w, 1m, ytd, 1y, all."
    )


def test_an_undeclared_option_names_the_option_and_the_view() -> None:
    assert options_rejection(SUMMARY, {"colour": "red"}) == (
        "Option 'colour' is not declared by view 'portfolio.summary.v1'."
    )


def test_an_out_of_range_value_is_not_echoed() -> None:
    sentence = options_rejection(StandIn(), {"low": 99})  # type: ignore[arg-type]

    assert sentence == "Option 'low' is out of range for view 'stand.in.v1'."
    assert "99" not in sentence


def test_an_enum_behind_a_ref_is_followed() -> None:
    sentence = options_rejection(StandIn(), {"shade": "neon"})  # type: ignore[arg-type]

    assert sentence == "Option 'shade' must be one of: light, dark."


def test_a_nullable_choice_names_its_values() -> None:
    sentence = options_rejection(StandIn(), {"side": "hold"})  # type: ignore[arg-type]

    assert sentence == "Option 'side' must be one of: buy, sell."


def test_a_rule_across_options_names_no_single_option() -> None:
    sentence = options_rejection(StandIn(), {"low": 5, "high": 1})  # type: ignore[arg-type]

    assert sentence == "These options do not fit together for view 'stand.in.v1'."
