"""The DTO of ``activity.timeline.v1`` — the Activity tab, written down (spec 0028).

`Activity.dc.html`: *"Transaction history as a grouped, date-sectioned
timeline. Filter chips scope by type; each row carries a type icon,
price/quantity subtitle, and a right-aligned amount (buys neutral, dividends
green +, sells colored by realized P/L). Sell rows add a tax-lot badge —
amber ST, teal LT."* Every word here is the server's (N-9); the client draws
icons and colours from ``kind`` and ``tone``.

**The income kind is a staking reward, not a dividend (spec 0044 OD-7)**: the
sentence above was written over an equities ledger. The *shape* is unchanged —
income is still green and still carries a ``+``.
"""

from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.day_change import Trend
from app.presentation.displays import MoneyDisplay
from app.presentation.fragments import ProjectionDto

VIEW_ID: Final[str] = "activity.timeline.v1"
TITLE: Final[str] = "Activity"
NOTE: Final[str] = "Simulated activity — resets each session."
SUMMARY: Final[str] = (
    "The Activity tab: the ledger as a timeline grouped under today, this week "
    "and each month, filtered by kind, every row captioned and its amount "
    "signed the way the design colours it."
)
Kind = Literal["all", "buy", "sell", "staking_reward", "deposit"]
EntryKind = Literal["buy", "sell", "staking_reward", "deposit"]
Term = Literal["short", "long"]


class Filter(BaseModel):
    """One chip of the filter row."""

    model_config = ConfigDict(frozen=True)

    key: Kind = Field(description="The `kind` option this chip sets.")
    label: str = Field(max_length=16, description="The chip's words.")


FILTERS: Final[tuple[Filter, ...]] = (
    Filter(key="all", label="All"),
    Filter(key="buy", label="Buys"),
    Filter(key="sell", label="Sells"),
    Filter(key="staking_reward", label="Staking"),
    Filter(key="deposit", label="Deposits"),
)
BADGES: Final[dict[str, str]] = {
    "buy": "Buy",
    "sell": "Sell",
    "staking_reward": "Staking",
    "deposit": "Deposit",
}
#: What the tab says when the filters keep nothing — server-written like
#: every other word here, so the client composes no sentence of its own (N-9).
EMPTY: Final[str] = "No activity matches this filter."


class TermBadge(BaseModel):
    """The tax-lot badge a sell row carries — amber short, teal long."""

    model_config = ConfigDict(frozen=True)

    term: Term = Field(description="Which colour the badge takes.")
    label: str = Field(max_length=12, description="Its words.", examples=["ST gain"])


class RealizedLine(BaseModel):
    """``+$588 realized`` under a sell's amount."""

    model_config = ConfigDict(frozen=True)

    amount: MoneyDisplay = Field(description="The realised result, signed.")
    text: str = Field(max_length=32, description="The line, whole.")
    trend: Trend = Field(description="Its colour.")


class ActivityEntry(BaseModel):
    """One row of the timeline."""

    model_config = ConfigDict(frozen=True)

    key: str = Field(max_length=32, description="The ledger row's id.")
    kind: EntryKind = Field(description="Picks the icon and the sign.")
    title: str = Field(max_length=48, description="``Bought 1.6 BTC``.")
    detail: str = Field(max_length=64, description="``1.6 units @ $36,000.00``.")
    amount: MoneyDisplay = Field(description="Right-aligned, signed as drawn.")
    tone: Trend = Field(description="The amount's colour: up green, flat neutral.")
    badge: str = Field(max_length=12, description="``Buy`` · ``Staking``.")
    realized: RealizedLine | None = Field(default=None, description="Sells only.")
    term: TermBadge | None = Field(default=None, description="Sells only.")


class ActivityGroup(BaseModel):
    """A dated section: ``TODAY``, ``THIS WEEK``, ``SEPTEMBER 2026``."""

    model_config = ConfigDict(frozen=True)

    label: str = Field(max_length=24, description="The section heading.")
    entries: tuple[ActivityEntry, ...] = Field(
        max_length=200, description="The rows under it, newest first."
    )


class ActivityTimelinePayload(ProjectionDto):
    """Everything the Activity tab binds."""

    view: Literal["activity.timeline.v1"] = Field(
        default=VIEW_ID, description="The projection id, for the discriminator."
    )
    title: str = Field(default=TITLE, max_length=32, description="The tab's title.")
    note: str = Field(default=NOTE, max_length=64, description="The simulation note.")
    kind: Kind = Field(description="The filter this render honoured.")
    query: str | None = Field(
        default=None,
        max_length=24,
        description="The search this render honoured; absent when unfiltered.",
    )
    filters: tuple[Filter, ...] = Field(
        default=FILTERS, max_length=8, description="The chips, in order."
    )
    empty: str = Field(
        default=EMPTY, max_length=48, description="Shown when nothing matched."
    )
    groups: tuple[ActivityGroup, ...] = Field(
        max_length=64, description="The dated sections, newest first."
    )


__all__ = [
    "BADGES",
    "EMPTY",
    "FILTERS",
    "NOTE",
    "SUMMARY",
    "TITLE",
    "VIEW_ID",
    "ActivityEntry",
    "ActivityGroup",
    "ActivityTimelinePayload",
    "EntryKind",
    "Filter",
    "Kind",
    "RealizedLine",
    "TermBadge",
]
