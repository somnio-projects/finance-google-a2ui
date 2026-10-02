"""The DTO of ``attribution.driver.v1`` — Flow A's drill-down card (spec 0032).

What `FlowA-Assistant.dc.html`'s D2 state draws below the waterfall once a
bar is tapped: the ticker chip, the name, a caption placing the holding among
the day's movers, its contribution, and three tiles — the price move, the
units held at their price, and the share of the day's gain. Every number is
an ADR-E pair; every word, including the tile captions ``@ $64,250.00`` and
``of +$2,201.05``, is written here (N-9).

**The second tile was called** ``shares`` **and labelled "Shares"** while it
held 2.1 Bitcoin (GGU-123). Both are gone: the field is ``holding`` and the
label is the asset's own ticker, which the payload already knows — so the tile
names a unit the asset class actually has instead of one it does not. The
rename is client-breaking, which is why it shipped as one release across the
projection, the A2UI adapter, both catalog artefacts and the Dart binding.
"""

from typing import Final, Literal

from pydantic import Field

from app.domain.day_change import Trend
from app.presentation.fragments import (
    Labelled,
    MoneyDisplay,
    PercentageDisplay,
    ProjectionDto,
)
from app.presentation.ticket_displays import QuantityDisplay

VIEW_ID: Final[str] = "attribution.driver.v1"
SUMMARY: Final[str] = (
    "One holding's part in today's move: its contribution, the price move "
    "behind it, the units that carried it and its share of the day's result. "
    "The card a tapped waterfall bar opens."
)
#: The tile labels, as the design prints them.
PRICE_MOVE_LABEL: Final[str] = "Price move"
#: The units tile's label, per asset: ``BTC held``. A template rather than a
#: noun, because the honest unit word is the asset's own (GGU-123 AC-1).
HOLDING_LABEL: Final[str] = "{symbol} held"
DAY_GAIN_LABEL: Final[str] = "Of day gain"
DAY_LOSS_LABEL: Final[str] = "Of day loss"


class PriceMove(Labelled):
    """How far the unit price moved today, as a ratio and as money."""

    percent: PercentageDisplay = Field(description="Signed day move of the price.")
    amount: MoneyDisplay = Field(description="The same move in currency, signed.")
    trend: Trend = Field(description="Direction, so the widget picks the glyph.")


class HoldingUnits(Labelled):
    """How many units carried the move, and at what price."""

    units: QuantityDisplay = Field(description="Units held.")
    price: MoneyDisplay = Field(description="Today's unit price, as quoted.")
    caption: str = Field(
        max_length=40,
        description="The line under the count, written here.",
        examples=["@ $64,250.00"],
    )


class DayShare(Labelled):
    """What share of the portfolio's day this holding was."""

    percent: PercentageDisplay = Field(
        description=(
            "Contribution over the day's move. Above 100% when the rest of the "
            "portfolio moved the other way; negative when this holding did."
        )
    )
    total: MoneyDisplay = Field(description="The portfolio's day move, signed.")
    caption: str = Field(
        max_length=40,
        description="The line under the share, written here.",
        examples=["of +$3,240.18"],
    )


class DriverDetailPayload(ProjectionDto):
    """Everything the drill-down card puts on screen."""

    view: Literal["attribution.driver.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    symbol: str = Field(
        max_length=10,
        description="Ticker, as the chip prints it. Also the option that selects it.",
        examples=["BTC"],
    )
    name: str = Field(
        max_length=64, description="Display name.", examples=["NVIDIA Corp"]
    )
    caption: str = Field(
        max_length=48,
        description="Where the holding stands among today's movers.",
        examples=["Top contributor today"],
    )
    contribution: MoneyDisplay = Field(description="What it added today, signed.")
    trend: Trend = Field(description="Direction of the contribution.")
    price_move: PriceMove = Field(description="The first tile.")
    holding: HoldingUnits = Field(description="The second tile.")
    day_share: DayShare = Field(description="The third tile.")


#: The caption per standing; ``{rank}`` is filled for the ranked ones.
CAPTIONS: Final[dict[str, str]] = {
    "top_contributor": "Top contributor today",
    "contributor": "#{rank} contributor today",
    "top_detractor": "Top detractor today",
    "detractor": "#{rank} detractor today",
    "unchanged": "Unchanged today",
}

__all__ = [
    "CAPTIONS",
    "DAY_GAIN_LABEL",
    "DAY_LOSS_LABEL",
    "HOLDING_LABEL",
    "PRICE_MOVE_LABEL",
    "SUMMARY",
    "VIEW_ID",
    "DayShare",
    "DriverDetailPayload",
    "HoldingUnits",
    "PriceMove",
]
