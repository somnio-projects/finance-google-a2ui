"""Write a ``DriverDetail`` down as the pairs and words the card binds (0032).

The arithmetic is ``app.domain.driver``'s; this module only formats it under
the render's options and writes the captions. Pure, like everything here.
"""

from app.domain.day_change import trend_of
from app.domain.driver import DriverDetail
from app.presentation import driver_payload as words
from app.presentation.displays import percentage, signed_money, signed_percentage
from app.presentation.driver_payload import (
    DayShare,
    DriverDetailPayload,
    PriceMove,
    SharesHeld,
)
from app.presentation.options import DisplayOptions
from app.presentation.ticket_displays import price, quantity


def caption_for(detail: DriverDetail) -> str:
    """Where the holding stands among today's movers, in the design's words."""
    return words.CAPTIONS[detail.standing].format(rank=detail.rank)


def price_move(detail: DriverDetail, options: DisplayOptions) -> PriceMove:
    """The first tile: how far the unit price moved today."""
    return PriceMove(
        label=words.PRICE_MOVE_LABEL,
        percent=signed_percentage(
            detail.price_ratio, precision=options.precision, locale=options.locale
        ),
        amount=signed_money(
            detail.price_change, precision=options.precision, locale=options.locale
        ),
        trend=trend_of(detail.price_change),
    )


def shares_held(detail: DriverDetail, options: DisplayOptions) -> SharesHeld:
    """The second tile: the units that carried the move, at their price."""
    unit_price = price(detail.price, locale=options.locale)
    return SharesHeld(
        label=words.SHARES_LABEL,
        units=quantity(detail.quantity, locale=options.locale),
        price=unit_price,
        caption=f"@ {unit_price.display}",
    )


def day_share(detail: DriverDetail, options: DisplayOptions) -> DayShare:
    """The third tile: the holding's share of the portfolio's day."""
    total = signed_money(
        detail.day_gain, precision=options.precision, locale=options.locale
    )
    return DayShare(
        label=words.DAY_LOSS_LABEL if detail.day_gain < 0 else words.DAY_GAIN_LABEL,
        percent=percentage(
            detail.share, precision=options.precision, locale=options.locale
        ),
        total=total,
        caption=f"of {total.display}",
    )


def payload_for(detail: DriverDetail, options: DisplayOptions) -> DriverDetailPayload:
    """Assemble the whole card from one domain result."""
    return DriverDetailPayload(
        symbol=detail.symbol,
        name=detail.name,
        caption=caption_for(detail),
        contribution=signed_money(
            detail.contribution, precision=options.precision, locale=options.locale
        ),
        trend=trend_of(detail.contribution),
        price_move=price_move(detail, options),
        shares=shares_held(detail, options),
        day_share=day_share(detail, options),
    )


__all__ = ["caption_for", "day_share", "payload_for", "price_move", "shares_held"]
