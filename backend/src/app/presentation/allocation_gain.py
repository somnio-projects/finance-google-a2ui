"""The all-time gain under the allocation total (spec 0026).

Split out of ``views/holdings_allocation`` when GGU-145 added the grouping
toggle and the module passed the 150-line budget. The seam is the one the
package already uses: ``allocation_rows`` turns holdings into slices,
``allocation_groups`` turns the option into segments, and this turns the
portfolio into the one figure printed under the total.
"""

from typing import Final

from app.core.signed_display import signed_money_display, signed_percentage_display
from app.domain.day_change import change_ratio, trend_of
from app.domain.portfolio import Portfolio
from app.presentation.allocation_options import HoldingsAllocationOptions
from app.presentation.displays import MoneyDisplay, PercentageDisplay
from app.presentation.summary_payload import Change

#: The period the design labels this gain with.
ALL_TIME: Final[str] = "all-time"


def gain(portfolio: Portfolio, options: HoldingsAllocationOptions) -> Change:
    """Return the all-time gain the design prints under the total.

    Args:
        portfolio: The domain data; never fetched here.
        options: The validated options, for `locale` and `precision`.

    Returns:
        The change block, every figure already formatted.
    """
    cost = portfolio.total_cost_basis()
    delta = portfolio.total_unrealized_pl()
    ratio = change_ratio(portfolio.total_market_value(), cost)
    return Change(
        amount=MoneyDisplay(
            amount=delta,
            display=signed_money_display(delta, precision=0, locale=options.locale),
        ),
        percent=PercentageDisplay(
            value=ratio,
            display=signed_percentage_display(
                ratio, precision=1, locale=options.locale
            ),
        ),
        trend=trend_of(delta),
        period=ALL_TIME,
    )


__all__ = ["ALL_TIME", "gain"]
