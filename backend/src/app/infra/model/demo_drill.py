"""The turn a tapped attribution bar runs on a stack without a model key.

``drill.attribution.v1`` composes *Break down the contribution of {S}…* for
every symbol the market reference knows (spec 0022); the scripted model
answers it by calling ``driver_detail`` (spec 0032), whose card is the day's
by definition — the design's *Top contributor today*. A symbol the portfolio
does not hold makes the tool answer ``held: false`` with nothing to draw, and
the script then says so in a sentence of its own (spec 0033 OD-3).
"""

from typing import Final

from app.actions.defined.drill_attribution import ANSWER, DRIVER_TOOL, NOT_HELD
from app.infra.model.script import Script, ScriptedCall

DRIVER: Final[str] = DRIVER_TOOL


def drill(symbol: str) -> Script:
    """Return the turn a tapped waterfall bar for ``symbol`` runs (0033 OD-3)."""
    return Script(
        calls=(ScriptedCall(DRIVER, {"symbol": symbol}),),
        # One sentence for both paths: a tapped drill runs with no model and
        # says ANSWER itself (spec 0056); a typed one reaches this script.
        answer=ANSWER,
        otherwise=NOT_HELD.format(symbol=symbol),
    )


__all__ = ["DRIVER", "drill"]
