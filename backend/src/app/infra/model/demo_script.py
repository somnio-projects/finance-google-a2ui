"""The demo's table: which prompt runs which tools, and what is then said.

Every key is a sentence the backend already owns — the four curated chips
(``app.actions.suggestions``), the drill an attribution bar composes, and the
three questions the design's Flow A, B and C artboards open with. The chip and
drill keys are built by calling the actions' own ``compose``, so the table
cannot drift from the prompt a tap actually produces (spec 0033 OD-1).

Tool names are spelled here as the model would spell them; a test resolves
each one against the discovered registry, so a renamed tool fails the gate
rather than a demo. Every figure in a sentence is a hole a tool fills
(``app.infra.model.script``); the only literals are words.
"""

from collections.abc import Mapping
from typing import Final

from app.actions.defined.ask_suggested import AskSuggestedArgs
from app.actions.defined.ask_suggested import compose as chip_prompt
from app.actions.defined.drill_attribution import DrillAttributionArgs
from app.actions.defined.drill_attribution import compose as drill_prompt
from app.domain.market import MARKET_REFERENCE
from app.infra.model.demo_drill import drill
from app.infra.model.script import Script, ScriptedCall, normalise

ATTRIBUTION: Final[str] = "compute_attribution"
HOLDINGS: Final[str] = "get_holdings_summary"
SALE: Final[str] = "simulate_sale"
DRAFT: Final[str] = "draft_order"

#: The questions the design's three flows open with, byte for byte.
FLOW_A: Final[str] = "What moved my portfolio today?"
FLOW_B: Final[str] = "If I sell $20k of BTC, what's the tax hit?"
FLOW_C: Final[str] = "Put about $10k into the majors, keep it diversified."

#: Flow B's sale and Flow C's order, as the design states them. A user's own
#: amount is an argument, not a figure: the tool turns it into units.
DESIGN_SALE: Final[Mapping[str, object]] = {
    "symbol": "BTC",
    "amount_usd": "20000",
    "lot_method": "FIFO",
}
DESIGN_ORDER: Final[Mapping[str, object]] = {
    "amount": "10000",
    "basket": "majors",
}

_MOVED: Final[str] = "Your portfolio is {trend} {changeDisplay} ({changePctDisplay})"
_SOLD: Final[str] = (
    "{summary.quantityDisplay} {summary.symbol} sold under {summary.lotMethod} "
    "raises {summary.proceedsDisplay} and realises {summary.realizedPlDisplay}"
)

FLOW_SCRIPTS: Final[Mapping[str, Script]] = {
    FLOW_A: Script(
        calls=(ScriptedCall(ATTRIBUTION, {"window": "1d"}),),
        answer=f"{_MOVED} today. Here's what drove it:",
    ),
    FLOW_B: Script(
        calls=(ScriptedCall(SALE, DESIGN_SALE),),
        answer=(
            f"{_SOLD}: {{summary.shortTermPlDisplay}} short-term and "
            "{summary.longTermPlDisplay} long-term. The tax itself depends on "
            "your rate, which I don't apply; nothing is traded."
        ),
    ),
    FLOW_C: Script(
        calls=(ScriptedCall(DRAFT, DESIGN_ORDER),),
        answer=(
            "Here is a draft across the majors basket: "
            "{impact.totalDisplay} in {impact.unitsDisplay} units, fees "
            "{impact.feesDisplay}, leaving {impact.cashRemainingDisplay} in cash "
            "of {constraints.maxCashDisplay}. Edit the legs on the ticket; "
            "nothing is placed."
        ),
    ),
}

#: Suggestion key → the turn its chip runs. A test holds this against
#: ``DECLARED_KEYS``, so a chip added to one table and not the other fails.
CHIP_SCRIPTS: Final[Mapping[str, Script]] = {
    "allocation": Script(
        calls=(ScriptedCall(HOLDINGS, {}),),
        answer=(
            "Your portfolio is worth {totals.marketValueDisplay}, "
            "{totals.unrealizedPlDisplay} ({totals.unrealizedPlPctDisplay}) on "
            "what it cost. Here is how it is allocated, largest first:"
        ),
    ),
    "biggest-drivers": Script(
        calls=(ScriptedCall(ATTRIBUTION, {"window": "7d"}),),
        answer=(
            f"{_MOVED} over the last week. The holdings that moved it most are "
            "drawn first:"
        ),
    ),
    "tax-lots": Script(
        calls=(ScriptedCall(SALE, DESIGN_SALE),),
        answer=(f"As the example, {_SOLD}, split by term below. Nothing is traded."),
    ),
    "why-did-i-move": Script(
        calls=(ScriptedCall(ATTRIBUTION, {"window": "7d"}),),
        answer=f"{_MOVED} over the last week. Here's what drove it:",
    ),
}


def _chip_key(key: str) -> str:
    """Return the prompt ``ask.suggested.v1`` composes for ``key``, normalised."""
    return normalise(chip_prompt(AskSuggestedArgs.model_validate({"suggestion": key})))


def _drill_key(symbol: str) -> str:
    """Return the prompt ``drill.attribution.v1`` composes for ``symbol``."""
    args = DrillAttributionArgs.model_validate({"driver": symbol})
    return normalise(drill_prompt(args))


#: Normalised prompt → script. Built once, at import, from the three sources.
DEMO_SCRIPTS: Final[Mapping[str, Script]] = {
    **{normalise(prompt): script for prompt, script in FLOW_SCRIPTS.items()},
    **{_chip_key(key): script for key, script in CHIP_SCRIPTS.items()},
    **{_drill_key(asset.symbol): drill(asset.symbol) for asset in MARKET_REFERENCE},
}

__all__ = [
    "CHIP_SCRIPTS",
    "DEMO_SCRIPTS",
    "DESIGN_ORDER",
    "DESIGN_SALE",
    "FLOW_A",
    "FLOW_B",
    "FLOW_C",
    "FLOW_SCRIPTS",
]
