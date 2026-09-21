"""Reusable, bounded option mixins (ADR-K D-3).

Elasticity comes from **declared** options, never from a free-form DSL: every
knob is a field on a pydantic model, bounded, defaulted, described and
exemplified. ``extra="forbid"`` on the base is what turns an undeclared option
into a 422 instead of a best-effort guess — a projection that does not declare
``top_n`` rejects ``top_n``, it does not ignore it.

Shared knobs live here so the tenth chart reuses the vocabulary the first nine
established; a projection composes the mixins it actually honours.
"""

from decimal import Decimal
from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.core.errors import ValidationFailedError
from app.presentation.displays import MoneyDisplay, PercentageDisplay, money, percentage

Locale = Literal["en-US", "es-AR", "de-DE"]
SortOrder = Literal["value_desc", "value_asc", "label"]
MAX_SECTIONS: Final[int] = 8


class ProjectionOptions(BaseModel):
    """Base of every projection's options model — unknown fields are rejected."""

    model_config = ConfigDict(frozen=True, extra="forbid")


class CurrencyOptions(ProjectionOptions):
    """Which currency the figures are denominated in."""

    currency: Literal["USD"] = Field(
        default="USD",
        description=(
            "Currency of every figure. The portfolio is denominated in USD and "
            "the backend invents no exchange rate, so anything else is "
            "rejected rather than silently converted."
        ),
        examples=["USD"],
    )


class PrecisionOptions(ProjectionOptions):
    """How many decimal places the rendered figures carry."""

    precision: int = Field(
        default=2,
        ge=0,
        le=8,
        description="Decimal places for every figure this view renders.",
        examples=[2],
    )


class LocaleOptions(ProjectionOptions):
    """Which separators and currency placement the strings use."""

    locale: Locale = Field(
        default="en-US",
        description="Formatting locale for every rendered string.",
        examples=["en-US"],
    )


class SortOptions(ProjectionOptions):
    """In which order the rendered rows arrive."""

    sort: SortOrder = Field(
        default="value_desc",
        description="Row order: by value descending, ascending, or by label.",
        examples=["value_desc"],
    )


class TopNOptions(ProjectionOptions):
    """How many rows to show, and what happens to the rest."""

    top_n: int = Field(
        default=5,
        ge=1,
        le=20,
        description="How many rows to render before the residual bucket.",
        examples=[5],
    )
    include_other: bool = Field(
        default=True,
        description="Aggregate everything beyond `top_n` into an `Other` row.",
        examples=[True],
    )


class DisplayOptions(CurrencyOptions, PrecisionOptions, LocaleOptions):
    """Currency, precision and locale together, plus the formatting they imply."""

    def money(self, value: Decimal) -> MoneyDisplay:
        """Format ``value`` as a money pair under these options."""
        return money(value, precision=self.precision, locale=self.locale)

    def percentage(self, value: Decimal) -> PercentageDisplay:
        """Format a ``0..1`` ratio as a percentage pair under these options."""
        return percentage(value, precision=self.precision, locale=self.locale)


class FieldSelection(ProjectionOptions):
    """Which sections of the payload the widget actually binds (ADR-K D-21)."""

    fields: tuple[str, ...] | None = Field(
        default=None,
        max_length=MAX_SECTIONS,
        description=(
            "Sections to render; omit for all of them. A section this view "
            "does not offer is rejected, never ignored."
        ),
        examples=[["buckets"]],
    )

    def selected(self, available: tuple[str, ...]) -> tuple[str, ...]:
        """Return the sections to render, in ``available`` order.

        Raises:
            ValidationFailedError: When a selected section does not exist.
        """
        if self.fields is None:
            return available
        unknown = sorted(set(self.fields) - set(available))
        if unknown:
            msg = f"unknown section(s) {unknown}; this view offers {list(available)}"
            raise ValidationFailedError(msg)
        return tuple(name for name in available if name in self.fields)


__all__ = [
    "MAX_SECTIONS",
    "CurrencyOptions",
    "DisplayOptions",
    "FieldSelection",
    "Locale",
    "LocaleOptions",
    "PrecisionOptions",
    "ProjectionOptions",
    "SortOptions",
    "SortOrder",
    "TopNOptions",
]
