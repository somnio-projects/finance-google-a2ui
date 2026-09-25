"""The turn a tapped attribution bar runs on a stack without a model key.

``drill.attribution.v1`` composes *Break down the contribution of {S}…* for
every symbol the market reference knows (spec 0022); the scripted model
answers it by calling ``driver_detail`` (spec 0032), whose card is the day's
by definition — the design's *Top contributor today*. A symbol the portfolio
does not hold makes the tool answer ``held: false`` with nothing to draw, and
the script then says so in a sentence of its own (spec 0033 OD-3).
"""

from typing import Final

from app.infra.model.script import Script, ScriptedCall

DRIVER: Final[str] = "driver_detail"


def drill(symbol: str) -> Script:
    """Return the turn a tapped waterfall bar for ``symbol`` runs (0033 OD-3)."""
    return Script(
        calls=(ScriptedCall(DRIVER, {"symbol": symbol}),),
        answer=(
            "{name} ({symbol}) contributed {contributionDisplay} today: its price "
            "moved {priceMovePctDisplay} ({priceMoveDisplay}) on {sharesDisplay} "
            "units at {priceDisplay}, {shareOfDayDisplay} of the day's "
            "{dayGainDisplay}."
        ),
        otherwise=(
            f"{symbol} is not held in this portfolio, so there is no "
            "contribution to break down."
        ),
    )


__all__ = ["DRIVER", "drill"]
