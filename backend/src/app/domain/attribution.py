"""Window attribution — which holdings moved the portfolio, and by how much.

This answers *"why did my portfolio move over the last week?"*, which is a
different question from the unrealised profit and loss a holding carries. P/L
compares a position to what it **cost**; attribution compares it to what it was
worth at the **start of a window**. A holding bought years ago can be deeply
profitable and have contributed nothing this week.

**The waterfall must close.** Every contribution is computed from the same two
price series the totals are computed from, so the parts sum to the whole by
construction rather than by rounding luck — asserted in the tests, because a
waterfall whose bars do not reach its own end bar is worse than no chart.

Pure and deterministic: the prices come from the portfolio, the window is an
argument, and nothing here reads a clock (ADR-F D-6).
"""

from datetime import timedelta
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.errors import WindowOutOfRangeError
from app.domain.money import ZERO, Money
from app.domain.portfolio import Portfolio
from app.domain.symbols import SYMBOL_PATTERN


class Contribution(BaseModel):
    """One holding's share of the portfolio's move over the window."""

    model_config = ConfigDict(frozen=True)

    symbol: str = Field(pattern=SYMBOL_PATTERN, description="Ticker of the asset.")
    name: str = Field(min_length=1, max_length=64, description="Display name.")
    start_value: Money = Field(description="What the position was worth at the open.")
    end_value: Money = Field(description="What it is worth at ``as_of``.")
    contribution: Money = Field(description="``end_value - start_value``, in USD.")
    share: Decimal = Field(
        description=(
            "This contribution divided by the portfolio's total move; negative "
            "when the holding moved against it. Zero when the portfolio did "
            "not move, because a share of nothing would mislead the chart."
        )
    )


class WindowAttribution(BaseModel):
    """The portfolio's move over a window, split by holding."""

    model_config = ConfigDict(frozen=True)

    days: int = Field(ge=0, description="Length of the window, in days.")
    start_value: Money = Field(description="Portfolio value at the window's open.")
    end_value: Money = Field(description="Portfolio value at ``as_of``.")
    change: Money = Field(description="``end_value - start_value``, in USD.")
    change_ratio: Decimal = Field(
        description="``change / start_value``; zero when the open was zero."
    )
    contributions: tuple[Contribution, ...] = Field(
        default=(), description="Biggest absolute mover first."
    )

    def closes(self) -> bool:
        """Return True when the contributions sum exactly to ``change``.

        Returns:
            Whether the bars reach the end bar. Exact, not within an epsilon:
            every figure is a ``Decimal`` from the same prices, so drift would
            be a real defect rather than float noise.
        """
        return (
            sum((row.contribution for row in self.contributions), ZERO) == self.change
        )


def _ratio(numerator: Decimal, denominator: Decimal) -> Decimal:
    """Return the ratio, or zero when the denominator is zero."""
    if denominator == ZERO:
        return ZERO
    return numerator / denominator


def attribute_window(
    portfolio: Portfolio,
    *,
    window: timedelta,
    symbols: frozenset[str] | None = None,
) -> WindowAttribution:
    """Split the portfolio's move over ``window`` across its holdings.

    Args:
        portfolio: The portfolio to read; never fetched here.
        window: How far back the window opens from ``as_of``. A zero window is
            allowed and yields a flat result rather than an error.
        symbols: Restrict the attribution to these tickers. ``None`` means
            every holding. The totals cover **only** the selected holdings, so
            a filtered waterfall still closes against its own total.

    Returns:
        The attribution, contributions ordered by absolute size descending and
        ties broken by symbol so the order is total rather than merely sorted.

    Raises:
        WindowOutOfRangeError: When ``window`` is negative — a programming
            error, not a truncation.
    """
    if window < timedelta(0):
        msg = f"attribution window must not be negative, got {window}"
        raise WindowOutOfRangeError(msg)

    # Open each position at the window's first price, then let the totals fall
    # out of the same numbers: closure is then structural, not a coincidence.
    opened = [
        (
            holding,
            holding.quantity * portfolio.price_series(holding.symbol, window)[0].price,
        )
        for holding in portfolio.holdings()
        if symbols is None or holding.symbol in symbols
    ]
    start_total = sum((start for _, start in opened), ZERO)
    end_total = sum((holding.market_value for holding, _ in opened), ZERO)
    change = end_total - start_total

    rows = sorted(
        (
            Contribution(
                symbol=holding.symbol,
                name=holding.name,
                start_value=start,
                end_value=holding.market_value,
                contribution=holding.market_value - start,
                share=_ratio(holding.market_value - start, change),
            )
            for holding, start in opened
        ),
        key=lambda row: (-abs(row.contribution), row.symbol),
    )
    return WindowAttribution(
        days=window.days,
        start_value=start_total,
        end_value=end_total,
        change=change,
        change_ratio=_ratio(change, start_total),
        contributions=tuple(rows),
    )


__all__ = ["Contribution", "WindowAttribution", "attribute_window"]
