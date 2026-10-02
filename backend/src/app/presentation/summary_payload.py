"""The DTO of ``portfolio.summary.v1`` — the Home hero, written down (spec 0026).

Everything `Home.dc.html` prints above the tab bar that is not a catalog
component: the greeting, who the portfolio belongs to, the total, what moved
and over which period, the sparkline, the suggested questions and the day's
movers. Every number is an ADR-E pair; every word is server-written (N-9).
"""

from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.day_change import Trend
from app.presentation.displays import MoneyDisplay, PercentageDisplay
from app.presentation.fragments import ProjectionDto, Total

VIEW_ID: Final[str] = "portfolio.summary.v1"
TITLE: Final[str] = "Total portfolio value"
SUMMARY: Final[str] = (
    "The Home hero: total value, the change over a selected period with its "
    "direction, a thirty-day sparkline, the owner's greeting, suggested "
    "questions for the assistant and the day's top movers."
)


class Account(BaseModel):
    """Who the portfolio belongs to, as the header shows it."""

    model_config = ConfigDict(frozen=True)

    name: str = Field(
        max_length=64, description="Display name.", examples=["Alex Chen"]
    )
    initial: str = Field(max_length=2, description="Avatar monogram.", examples=["A"])


class Change(BaseModel):
    """A signed move: how much, what share, which way, over what period."""

    model_config = ConfigDict(frozen=True)

    amount: MoneyDisplay = Field(description="The move, signed and formatted.")
    percent: PercentageDisplay = Field(description="The move as a signed ratio.")
    trend: Trend = Field(description="Direction, so the widget picks the glyph.")
    period: str = Field(
        max_length=24, description="Words after it.", examples=["today"]
    )


class SparkPoint(BaseModel):
    """One day of the sparkline: a date label and the value that day."""

    model_config = ConfigDict(frozen=True)

    label: str = Field(
        max_length=16, description="The day, formatted.", examples=["09/18/2026"]
    )
    value: MoneyDisplay = Field(description="The portfolio's value that day.")


class Question(BaseModel):
    """One suggested question, exactly as the chip prints it."""

    model_config = ConfigDict(frozen=True)

    text: str = Field(
        max_length=80,
        description="The question.",
        examples=["What moved my portfolio today?"],
    )


class MoverRow(BaseModel):
    """One of the day's movers."""

    model_config = ConfigDict(frozen=True)

    symbol: str = Field(max_length=10, description="Ticker.", examples=["BTC"])
    name: str = Field(
        max_length=64, description="Display name.", examples=["NVIDIA Corp"]
    )
    price: MoneyDisplay = Field(description="Today's price.")
    change: PercentageDisplay = Field(description="Day change, signed.")
    trend: Trend = Field(description="Direction, so the widget picks the glyph.")


class PortfolioSummaryPayload(ProjectionDto):
    """Everything the Home hero puts on screen."""

    view: Literal["portfolio.summary.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    greeting: str = Field(
        max_length=24, description="Time-of-day greeting.", examples=["Good morning"]
    )
    account: Account = Field(description="Whose portfolio this is.")
    badge: str = Field(
        max_length=32,
        description="The simulation notice.",
        examples=["Simulated portfolio"],
    )
    total: Total = Field(description="The headline figure.")
    change: Change = Field(description="What moved over the selected range.")
    spark: tuple[SparkPoint, ...] = Field(
        description="Thirty daily values, oldest first."
    )
    questions_title: str = Field(
        max_length=32, description="Section heading.", examples=["Suggested questions"]
    )
    questions: tuple[Question, ...] = Field(description="Chips the assistant answers.")
    movers_title: str = Field(
        max_length=32, description="Section heading.", examples=["Top movers today"]
    )
    movers: tuple[MoverRow, ...] = Field(description="The day's movers, largest first.")


__all__ = [
    "SUMMARY",
    "TITLE",
    "VIEW_ID",
    "Account",
    "Change",
    "MoverRow",
    "PortfolioSummaryPayload",
    "Question",
    "SparkPoint",
]
