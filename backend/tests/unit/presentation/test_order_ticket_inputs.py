"""GGU-78 — the ticket names every editable option after the option itself.

`.claude/rules/backend/presentation.md` §4: *an editable field is a payload
field named exactly as the option that sets it; that naming **is** the
interactivity declaration.* ``order.ticket.v1`` offered four controls and
named two, so the generated contract reported two — the registry-wide guard
now lives in ``test_declared_interactivity.py`` and these pin the ticket that
exposed it.
"""

from app.domain.portfolio import Portfolio
from app.presentation.order_sizing import LABELS, OrderTicketOptions
from app.presentation.views.order_ticket import render


def test_every_editable_option_is_a_payload_field_of_exactly_its_own_name(
    portfolio: Portfolio,
) -> None:
    """GGU-78 — the naming *is* the interactivity declaration (0019 OD-3).

    ``size`` and ``size_in`` were offered as controls and carried by no field
    of that name, so the generated contract reported the ticket as accepting
    two of its four inputs. The registry-wide guard lives in
    ``test_declared_interactivity.py``; this pins the ticket itself.
    """
    payload = render(
        portfolio, OrderTicketOptions(symbol="SOL", side="sell", size="2.5")
    )

    assert set(LABELS) <= set(payload.model_dump())
    assert (payload.symbol, payload.side) == ("SOL", "sell")
    assert (payload.size, payload.size_in) == ("2.5", "units")


def test_the_size_a_ticket_echoes_is_what_was_asked_for_not_what_was_derived(
    portfolio: Portfolio,
) -> None:
    """GGU-78 — `quantity` is an output of `size`, so it is not an input.

    Under `size_in="usd"` the two differ, which is exactly why renaming
    `quantity` to `size` would have published a bound the options model does
    not accept: `size` must come back as the dollar figure the caller sent.
    """
    payload = render(
        portfolio, OrderTicketOptions(symbol="DOGE", size="500", size_in="usd")
    )

    assert (payload.size, payload.size_in) == ("500", "usd")
    assert payload.quantity.display == "3927.72977219"
