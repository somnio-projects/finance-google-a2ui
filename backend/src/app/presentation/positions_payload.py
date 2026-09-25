"""The DTO of ``holdings.positions.v1`` — the Holdings tab's list (spec 0028).

`Holdings.dc.html`: *"a data-dense position list. Each row carries a thin
left-border accent encoding today's move … revealing the 'Ask the assistant'
hand-off. Tabular figures throughout."* Every figure is an ADR-E pair; every
word — the caption under a name, the hand-off's label, the question it sends
— is server-written (N-9).
"""

from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.day_change import Trend
from app.domain.taxonomy import ASSET_CLASS_LABELS, AssetClass
from app.presentation.displays import MoneyDisplay, PercentageDisplay
from app.presentation.fragments import ProjectionDto, Total
from app.presentation.summary_payload import Change, Question

VIEW_ID: Final[str] = "holdings.positions.v1"
TITLE: Final[str] = "Holdings"
TOTAL_LABEL: Final[str] = "Total value"
GAIN_PERIOD: Final[str] = "all-time unrealized"
ASK_LABEL: Final[str] = "Ask the assistant about this"
CASH_DETAIL: Final[str] = "Settlement fund"
EMPTY: Final[str] = "No holdings match this filter."
AssetFilter = Literal["all", "layer1", "layer2", "stablecoin", "defi", "infrastructure"]
ALL_CLASSES: Final[AssetFilter] = "all"
SUMMARY: Final[str] = (
    "The Holdings tab: total value with the all-time gain, then one row per "
    "position — units and average cost, value, unrealised result, today's "
    "move, price and weight — each with the question that hands it to the "
    "assistant."
)


class ClassFilter(BaseModel):
    """One chip of the Holdings filter sheet.

    Deliberately not shared with ``activity_payload.Filter``: the two carry
    the same two field names and **different** closed key enums, and a single
    loose ``key: str`` fragment would lose both schemas to gain one class.
    """

    model_config = ConfigDict(frozen=True)

    key: AssetFilter = Field(description="The `asset_class` option it sets.")
    label: str = Field(max_length=16, description="The chip's words (N-9).")


#: The chips, in the donut's order, with the settlement asset where the
#: taxonomy puts it.
CLASS_FILTERS: Final[tuple[ClassFilter, ...]] = (
    ClassFilter(key=ALL_CLASSES, label="All"),
    *(
        ClassFilter(key=member.value, label=ASSET_CLASS_LABELS[member])
        for member in (
            AssetClass.LAYER1,
            AssetClass.LAYER2,
            AssetClass.INFRASTRUCTURE,
            AssetClass.DEFI,
            AssetClass.STABLECOIN,
        )
    ),
)


class Position(BaseModel):
    """One row of the list, everything already written down."""

    model_config = ConfigDict(frozen=True)

    symbol: str = Field(max_length=10, description="Ticker.", examples=["BTC"])
    name: str = Field(max_length=64, description="Display name.")
    detail: str = Field(
        max_length=48,
        description=(
            "The caption under the name: the quantity in the asset's own "
            "units, and the average cost."
        ),
        examples=["2.1 BTC · avg $41,698.00"],
    )
    value: MoneyDisplay = Field(description="Market value today.")
    unrealized: Change | None = Field(
        default=None,
        description="Gain or loss since purchase; absent for cash.",
    )
    day: PercentageDisplay = Field(description="Today's move, signed.")
    day_trend: Trend = Field(description="Direction of today's move.")
    price: MoneyDisplay = Field(description="Today's price per unit.")
    weight: PercentageDisplay = Field(description="Share of the portfolio.")
    is_cash: bool = Field(description="Whether this row is the settlement fund.")
    ask: Question = Field(description="What the hand-off sends the assistant.")


class HoldingsPositionsPayload(ProjectionDto):
    """Everything the Holdings tab binds."""

    view: Literal["holdings.positions.v1"] = Field(
        default=VIEW_ID, description="The projection id, for the discriminator."
    )
    title: str = Field(default=TITLE, max_length=32, description="The tab's title.")
    total: Total = Field(description="Total value, labelled.")
    gain: Change = Field(description="The all-time unrealised result.")
    ask_label: str = Field(
        default=ASK_LABEL, max_length=48, description="The hand-off's caption."
    )
    asset_class: AssetFilter = Field(
        default=ALL_CLASSES, description="The class filter this render honoured."
    )
    query: str | None = Field(
        default=None,
        max_length=24,
        description="The search this render honoured; absent when unfiltered.",
    )
    # Required rather than defaulted, unlike Activity's: the catalog prints
    # a defaulted field's default inside `FieldDescriptor.presence`, which is
    # bounded at 200 characters, and five class chips serialise to 204.
    # Passing them from `render` says the same thing and fits.
    filters: tuple[ClassFilter, ...] = Field(
        max_length=8, description="The chips, in order."
    )
    empty: str = Field(
        default=EMPTY, max_length=48, description="Shown when nothing matched."
    )
    positions: tuple[Position, ...] = Field(
        max_length=64, description="The rows, in the requested order."
    )


__all__ = [
    "ALL_CLASSES",
    "ASK_LABEL",
    "CASH_DETAIL",
    "CLASS_FILTERS",
    "EMPTY",
    "GAIN_PERIOD",
    "SUMMARY",
    "TITLE",
    "TOTAL_LABEL",
    "VIEW_ID",
    "AssetFilter",
    "ClassFilter",
    "HoldingsPositionsPayload",
    "Position",
]
