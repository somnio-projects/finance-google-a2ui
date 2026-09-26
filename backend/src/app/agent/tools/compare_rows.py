"""Display shaping for ``compare_lot_methods`` (spec 0052).

The same seam ``sale_rows`` cuts: **what the answer is** stays with the tool,
**how it reads** lives here. Every function is pure and returns nothing but
strings, so "did a raw number escape to the model?" is a question about one
file.

The per-method columns are ``sale_rows.summary`` verbatim — one simulation
rendered one way, whether it is the only one or one of three. What is new
here is the *subject*: the sale all the columns share, which is the premise
the card's title states and the sentence under it repeats.

It registers no tool; ``load_tools()`` imports it and nothing happens
(spec 0006 AC-7).
"""

from collections.abc import Mapping, Sequence

from app.core.display import price_display, quantity_display
from app.domain.sale_results import SaleSimulation

#: What separates the last two names in an English list. Written here because
#: it is display text, like every other string this module produces.
_AND: str = " and "


def methods_display(methods: Sequence[str]) -> str:
    """Return ``methods`` as the sentence names them: "FIFO, LIFO and HIFO".

    Takes **two or more**, and has no branch for one. That is not an
    unchecked assumption: ``CompareMethodsArguments.methods`` declares
    ``min_length=2``, so a single-method comparison cannot be expressed — the
    same structural refusal spec 0017 OD-3 makes for two symbols. A guard
    here would be a branch no caller can reach, which the coverage contract
    would then ask for a test that cannot exist.

    Args:
        methods: The methods being compared, in the order they are shown, at
            least two of them.

    Returns:
        A display string. The model copies it rather than assembling one,
        for the same reason it copies every figure: a list the model wrote
        could name a method the card does not draw.
    """
    return _AND.join([", ".join(methods[:-1]), methods[-1]])


def subject(result: SaleSimulation, *, methods: Sequence[str]) -> Mapping[str, object]:
    """Render the sale every column shares.

    Args:
        result: Any one of the simulations — they differ in which lots they
            consume, never in the symbol, the size or the price, which is the
            whole claim the card makes.
        methods: The methods being compared, in the order they are shown.

    Returns:
        The premise block: what is being sold, how much, at what price, and
        under which methods.
    """
    return {
        "symbol": result.symbol,
        "quantityDisplay": quantity_display(result.quantity, trim=True),
        "priceDisplay": price_display(result.price),
        "methodsDisplay": methods_display(methods),
    }


def render_options(
    result: SaleSimulation,
    *,
    methods: Sequence[str],
    include_wait: bool,
) -> Mapping[str, object]:
    """Name the comparison as ``scenario.comparison.v1`` declares its options.

    Args:
        result: The simulation, so the scenario named is the one that was
            actually costed — a dollar-sized ask has already become units.
        methods: The methods to draw, in order.
        include_wait: Whether to add the *Wait for long-term* column.

    Returns:
        The options of the render intent. No tax rate is named: the card
        prints the declared default it costs with, and a rate chosen here
        would be a tax claim nobody could check (GGU-134). ``quantity`` is
        formatted with ``:f`` rather than ``str()``, because a ``Decimal``
        quantized to eight places renders as ``1E-8`` in scientific notation
        and the view's bounded size pattern rejects it.
    """
    return {
        "symbol": result.symbol,
        "quantity": f"{result.quantity:f}",
        "methods": list(methods),
        "include_wait": include_wait,
    }


__all__ = ["methods_display", "render_options", "subject"]
