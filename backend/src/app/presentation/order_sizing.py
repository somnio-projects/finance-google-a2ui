"""The declared options of an order ticket, and how a size is expressed.

The presentation twin of ``app.agent.tools.payoff_order``, which asks the same
question for the payoff tool and answers it the same way: **one** ``size``
string plus a ``size_in`` unit rather than two optional numbers, because a
decimal that has been through a JSON float can no longer be made exact
(ADR-E D-5), and because two optional fields make three of four combinations
illegal states (spec 0014 OD-4).

Its own module for the reason ``payoff_order`` is one: the pair is over the
file budget, and this is the seam that was already there — *what a caller may
ask for*, apart from *what is rendered*.
"""

from decimal import Decimal
from typing import Final, Literal

from pydantic import Field

from app.domain.orders import order_quantity
from app.domain.payoff import Side
from app.domain.symbols import Symbol
from app.presentation.options import DisplayOptions

#: The assets a ticket may be written for: the curated market reference
#: (``app.domain.market``) spelled as a bound. Two declarations of one fact, so
#: a test compares them instead of a comment claiming they agree.

#: What a size counts. ``usd`` is divided by the entry price server-side.
SizeUnit = Literal["units", "usd"]

#: Nine integer digits and eight decimals, and nothing else. This is the
#: **whole** truth about what ``size`` accepts, because the ticket publishes it
#: to the widget as the bound that field enforces (spec 0018 AC-5).
SIZE_PATTERN: Final[str] = r"^[0-9]{1,9}(\.[0-9]{1,8})?$"

#: The editable options, in the order the widget lays them out.
LABELS: Final[dict[str, str]] = {
    "symbol": "Asset",
    "side": "Side",
    "size": "Size",
    "size_in": "Size in",
}


class OrderTicketOptions(DisplayOptions):
    """Declared knobs of ``order.ticket.v1``; nothing else is accepted."""

    symbol: Symbol = Field(
        default="BTC",
        description="Asset the order is written for, from the market reference.",
        examples=["SOL"],
    )
    side: Side = Field(
        default="buy",
        description="Which way the order goes; `sell` disposes of units held.",
        examples=["buy"],
    )
    size: str = Field(
        default="1",
        pattern=SIZE_PATTERN,
        description="How big the order is, as a decimal string (ADR-E D-5).",
        examples=["0.25"],
        # The reader's half of `pattern`, carried in the same schema so the two
        # cannot drift. `presentation.tickets` publishes it as `hint`; the
        # regex stays for the machine and is never drawn (spec 0026).
        json_schema_extra={"hint": "Up to 8 decimal places"},
    )
    size_in: SizeUnit = Field(
        default="units",
        description="What `size` counts: units of the asset, or US dollars.",
        examples=["usd"],
    )

    def units(self, price: Decimal) -> Decimal:
        """Return the units this order covers at ``price``.

        A dollar size is divided by the price **here**, through the domain's
        one division, so neither the model nor the client ever performs it
        (ADR-K D-5). A size of zero is a ticket for nothing rather than an
        error: the published bound admits it, and a bound that admits what the
        backend refuses is the defect this surface is tested against.

        Args:
            price: The entry price, from the market reference.

        Returns:
            The exact, unrounded unit count.
        """
        size = Decimal(self.size)
        if self.size_in == "units":
            return size
        return order_quantity(size, price)


__all__ = ["LABELS", "SIZE_PATTERN", "OrderTicketOptions", "SizeUnit", "Symbol"]
