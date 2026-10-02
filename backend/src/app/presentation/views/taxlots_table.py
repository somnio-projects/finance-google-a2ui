"""``taxlots.table.v1`` — the lots a proposed sale consumes (spec 0015).

Flow B's primary surface, and the first projection that renders something the
portfolio does not contain: a **sale**. The scenario therefore travels as
declared, bounded options (ADR-K D-3, ``taxlot_scenario``) and ``render``
calls the pure domain walk, which keeps the Protocol's
``(portfolio, options) → DTO`` signature honest — ``simulate_sale`` performs no
I/O, holds the finance itself and takes its ``as_of`` from the portfolio.

Spec 0015 OD-1 records what that costs: this ``render`` can raise a **data**
error, which no other projection can, and its defaults have to name a scenario
the seeded portfolio can satisfy, because the documented example is rendered at
defaults.
"""

from typing import Final

from app.domain.portfolio import Portfolio
from app.domain.sales import simulate_sale
from app.presentation import taxlot_render as build
from app.presentation.endpoints import PORTFOLIO_ENDPOINTS
from app.presentation.fragments import Total
from app.presentation.registry import register
from app.presentation.spec import ProjectionSpec
from app.presentation.surfaces import Surface
from app.presentation.taxlot_scenario import TaxLotsTableOptions
from app.presentation.taxlots import VIEW_ID, TaxLotsTablePayload
from app.presentation.taxlots_guidance import GUIDANCE

TITLE: Final[str] = "Tax lots this sale consumes"
SUMMARY: Final[str] = (
    "Tax-lot table for a proposed sale: the lots it consumes under FIFO, LIFO "
    "or HIFO, each with its holding period, and the realised result split "
    "short-term vs long-term. Nothing is traded."
)
#: The split is not among them: a table of disposals with no tax story is the
#: failure this component exists to prevent (spec 0015 OD-6). ``remaining``
#: left the payload with the notes it selected (spec 0024 §7).
SECTIONS: Final[tuple[str, ...]] = ("lots",)
NEVER_SELECTED: Final[int] = 0


def render(portfolio: Portfolio, options: TaxLotsTableOptions) -> TaxLotsTablePayload:
    """Cost the proposed sale and lay its lots out as a table (0015 AC-2).

    Args:
        portfolio: The domain result; never fetched here, always passed in.
        options: The validated, bounded options, scenario included.

    Returns:
        The payload the widget binds, every figure already formatted.

    Raises:
        SymbolNotFoundError: When the ticker is not in the market reference.
        SaleQuantityError: When the size is not a positive number of units.
        PositionTooSmallError: When the position holds fewer units. A scenario
            the data cannot satisfy fails loudly rather than rendering a
            plausible wrong table (spec 0015 AC-8).
    """
    sections = options.selected(SECTIONS)
    result = simulate_sale(
        portfolio,
        symbol=options.symbol,
        quantity=options.units(),
        method=options.method(),
    )
    return TaxLotsTablePayload(
        title=TITLE,
        subtitle=build.subtitle(result, options, method=options.lot_method),
        proceeds=Total(label="Proceeds", amount=options.money(result.proceeds)),
        cost_basis=Total(label="Cost basis", amount=options.money(result.cost_basis)),
        realized=build.realized_total(result, options),
        by_term=build.term_split(result, options),
        lots=tuple(build.lot_row(row, options) for row in result.consumed)
        if "lots" in sections
        else (),
    )


def surface(payload: TaxLotsTablePayload) -> Surface:
    """Map the payload onto the A2UI table the genui client instantiates."""
    totals = (payload.proceeds, payload.cost_basis, payload.realized)
    return Surface(
        component="TaxLotTable",
        view=payload.view,
        title=payload.title,
        props={
            "subtitle": payload.subtitle,
            "totals": [total.model_dump(mode="json") for total in totals],
            "byTerm": [half.model_dump(mode="json") for half in payload.by_term],
            "rows": [row.model_dump(mode="json") for row in payload.lots],
        },
    )


def fitness(portfolio: Portfolio) -> int:
    """Score 0 for every portfolio: a sale cannot be inferred (0015 AC-9)."""
    del portfolio  # nothing in the data proposes a trade; guessing one lies
    return NEVER_SELECTED


PROJECTION: Final = register(
    ProjectionSpec(
        id=VIEW_ID,
        summary=SUMMARY,
        endpoints=PORTFOLIO_ENDPOINTS,
        options=TaxLotsTableOptions,
        dto=TaxLotsTablePayload,
        render=render,
        surface=surface,
        fitness=fitness,
        guidance=GUIDANCE,
    )
)

__all__ = ["PROJECTION", "SECTIONS", "VIEW_ID", "render", "surface"]
