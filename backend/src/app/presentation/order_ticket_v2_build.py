"""From the domain's statements to the payload's fragments (spec 0031).

``draft_impact`` and ``draft_weights`` say what the order costs and shifts;
this module writes it down under the caller's locale and precision. Every
number leaves as an ADR-E pair, the validation sentence is composed here so
the client renders it verbatim (N-9), and the stepper values are the domain's
``stepped`` — the same parser and bound the options model enforces.

Split from the view module for the file budget, along the seam that was
already there: *what is rendered* apart from *how the projection is wired*.
"""

from decimal import Decimal

from app.domain.draft_impact import DraftImpact
from app.domain.draft_ladder import ladder
from app.domain.draft_legs import LegRequest, stepped
from app.domain.draft_weights import WeightShift as ShiftFigures
from app.domain.money import ZERO
from app.domain.payoff import Side
from app.presentation.fragments import Total
from app.presentation.order_ticket_v2_lines import OrderLine, WeightShift
from app.presentation.order_ticket_v2_options import OrderTicketV2Options
from app.presentation.order_ticket_v2_payload import (
    Badge,
    Breach,
    OrderConstraints,
    OrderImpact,
)
from app.presentation.ticket_displays import price, quantity

#: The panel's captions, server-written so the client spells none (N-9).
TOTAL_LABEL = "Total order"
FEES_LABEL = "Est. fees · sim"
CASH_LABEL = "Cash remaining"
MAX_CASH_LABEL = "Available cash"
WEIGHT_LABEL = "Portfolio weight · {group}"
OVER_CASH = "Exceeds available cash — reduce order by {shortfall}."


def title(requests: tuple[LegRequest, ...], side: Side) -> str:
    """Write the header: ``Draft order · Buy · 3 legs``."""
    count = len(requests)
    legs = "leg" if count == 1 else "legs"
    return f"Draft order · {side.capitalize()} · {count} {legs}"


def lines(
    impact: DraftImpact,
    requests: tuple[LegRequest, ...],
    options: OrderTicketV2Options,
) -> tuple[OrderLine, ...]:
    """Render every leg with its figures and every value its controls send.

    The stepper sets the **size** and the slider sets the **mix**: a tap
    moves this leg by one asset step and changes the order's total, a drag
    moves this leg's share and leaves the total where it is (spec 0050 OD-1).
    Both are written by the domain over the same option, and whichever is
    used, the next render's ladder is aligned to the value it sent.
    """
    rungs = {leg.symbol: ladder(requests, leg.symbol) for leg in impact.legs}
    return tuple(
        OrderLine(
            key=leg.symbol,
            symbol=leg.symbol,
            name=leg.name,
            price=price(leg.price, locale=options.locale),
            quantity=quantity(leg.quantity, locale=options.locale),
            notional=options.money(leg.notional),
            weight=options.percentage(leg.weight),
            increment=stepped(requests, leg.symbol, 1),
            decrement=stepped(requests, leg.symbol, -1),
            stops=rungs[leg.symbol].stops,
            position=rungs[leg.symbol].position,
        )
        for leg in impact.legs
    )


def impact_block(
    impact: DraftImpact,
    shifts: tuple[ShiftFigures, ...],
    options: OrderTicketV2Options,
) -> OrderImpact:
    """Render the *Order impact* panel."""
    return OrderImpact(
        total=Total(label=TOTAL_LABEL, amount=options.money(impact.total)),
        fees=Total(label=FEES_LABEL, amount=options.money(impact.fees)),
        cash_remaining=Total(label=CASH_LABEL, amount=options.money(impact.cash_after)),
        weight_shifts=tuple(
            WeightShift(
                key=shift.key,
                label=WEIGHT_LABEL.format(group=shift.label),
                before=options.percentage(shift.before),
                after=options.percentage(shift.after),
            )
            for shift in shifts
        ),
    )


def breach_of(impact: DraftImpact) -> Breach:
    """Name the bound the draft exceeds, if any."""
    return "over_cash" if impact.shortfall > ZERO else "none"


def badge_of(breach: Breach) -> Badge:
    """The header pill that goes with a breach."""
    return "blocked" if breach == "over_cash" else "editable"


def constraints_block(
    impact: DraftImpact, options: OrderTicketV2Options
) -> OrderConstraints:
    """Render the bound, and the breach with its sentence when there is one."""
    breach = breach_of(impact)
    shortfall: Decimal | None = impact.shortfall if breach == "over_cash" else None
    figure = None if shortfall is None else options.money(shortfall)
    return OrderConstraints(
        max_cash=Total(
            label=MAX_CASH_LABEL, amount=options.money(impact.cash_available)
        ),
        breach=breach,
        shortfall=figure,
        message=None if figure is None else OVER_CASH.format(shortfall=figure.display),
    )


__all__ = [
    "CASH_LABEL",
    "FEES_LABEL",
    "MAX_CASH_LABEL",
    "OVER_CASH",
    "TOTAL_LABEL",
    "WEIGHT_LABEL",
    "badge_of",
    "breach_of",
    "constraints_block",
    "impact_block",
    "lines",
    "title",
]
