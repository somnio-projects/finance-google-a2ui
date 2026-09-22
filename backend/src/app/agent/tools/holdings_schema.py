"""The JSON Schema ``get_holdings_summary`` advertises to the model.

Its own module because it is a different artefact from the argument model
beside it: this is what the *model* reads when it decides what to ask for,
and ``HoldingsSummaryArguments`` is what *pydantic* enforces when the answer
comes back. They describe the same knobs and neither generates the other —
``test_the_schema_the_model_reads_carries_the_same_bounds`` asserts they
agree, because two hand-written declarations of one contract is exactly the
drift this repository checks rather than trusts.
"""

from collections.abc import Mapping
from typing import Final

from app.agent.tools.holdings_grouping import GROUPINGS
from app.agent.tools.holdings_sort import SORTERS
from app.domain.symbols import MAX_TICKER, TICKER_PATTERN

MAX_TOP_N: Final[int] = 20
MAX_SYMBOLS: Final[int] = 20

#: The JSON Schema the model chooses its arguments from. It mirrors
#: ``HoldingsSummaryArguments``; the model reads this one, pydantic enforces
#: the other, and ``test_the_schema_the_model_reads_carries_the_same_bounds``
#: asserts the two agree rather than trusting this comment.
PARAMETERS: Final[Mapping[str, object]] = {
    "type": "object",
    "properties": {
        "sort_by": {
            "type": "string",
            "enum": list(SORTERS),
            "description": (
                "Order of the positions: 'weight' or 'value' for the largest "
                "first, 'gainers' or 'losers' for the best or worst return on "
                "what the position cost."
            ),
        },
        "symbols": {
            "type": "array",
            "items": {
                "type": "string",
                "maxLength": MAX_TICKER,
                "pattern": TICKER_PATTERN,
            },
            "maxItems": MAX_SYMBOLS,
            "description": "Keep only these tickers. Omit for every position.",
        },
        "top_n": {
            "type": "integer",
            "minimum": 1,
            "maximum": MAX_TOP_N,
            "description": "Keep only the first N positions after sorting.",
        },
        "group_by": {
            "type": "string",
            "enum": list(GROUPINGS),
            "description": (
                "How to slice the allocation chart that comes with an "
                "unfiltered answer: 'holding' is one slice per position, "
                "'asset_class' folds them into Equities, Bonds, Cash and "
                "Alternatives, 'sector' folds the equities by sector. Ask "
                "for the one the question asks about."
            ),
        },
    },
    "required": [],
    "additionalProperties": False,
}

__all__ = ["MAX_SYMBOLS", "MAX_TOP_N", "PARAMETERS"]
