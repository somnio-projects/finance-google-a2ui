"""The template a typed quantity is written into (spec 0054).

The stepper's ``+`` and ``-`` carry the whole ``legs`` value they send, because
this client may not add a step to a unit count (N-2). Typing a quantity is the
same edit with the number chosen by the person rather than by the step, so the
backend serves the rest of the value and leaves exactly one hole: the client
substitutes what was typed **verbatim** — no parsing, no rounding, no
formatting — and the options model judges the result like any other ``legs``
value. A malformed or out-of-range entry is therefore the same 422 (or
``INVALID_FUNCTION_CALL`` on the v1.0 wire) a hand-written URL would get.
"""

from typing import Final

from app.domain.draft_legs import LEG_SEPARATOR, QUANTITY_SEPARATOR, LegRequest

#: The one hole in an entry template. Braces cannot occur in a ``legs`` value
#: (``LEGS_PATTERN``), so the placeholder can never collide with a ticker or a
#: quantity, and a template that still contains it is never a valid option.
UNITS_PLACEHOLDER: Final[str] = "{units}"


def entry_template(legs: tuple[LegRequest, ...], symbol: str) -> str:
    """Return ``legs`` written out with ``symbol``'s units left as the hole.

    Args:
        legs: The legs as rendered, in the order written.
        symbol: The leg whose quantity the person types.

    Returns:
        The whole option value with ``UNITS_PLACEHOLDER`` in place of that
        leg's quantity — every other leg exactly as ``format_legs`` writes it.
    """
    return LEG_SEPARATOR.join(
        f"{leg.symbol}{QUANTITY_SEPARATOR}"
        f"{UNITS_PLACEHOLDER if leg.symbol == symbol else leg.quantity}"
        for leg in legs
    )


__all__ = ["UNITS_PLACEHOLDER", "entry_template"]
