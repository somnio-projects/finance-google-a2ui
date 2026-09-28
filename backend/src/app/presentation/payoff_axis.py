"""The value axis ``payoff.curve.v1`` draws, and the words either side of it.

Both blocks exist because the design draws something the client could not
bind without breaking a prohibition (GGU-146, spec ``frontend/0034``).

**The ladder.** The artboard labels its horizontal rules — ``+$20k``,
``+$15k``, ``$0`` — and the payload carried no such figure. A client that
picked its own rules and formatted them would be computing a figure and then
writing it (N-2 and N-1 in one step), and it would not follow ``locale``. So
the rungs are chosen and written **here**, and the client places a rule at
each ``amount`` and prints its ``display`` verbatim.

**The words.** The same artboard writes *Loss* and *Gain* inside the two
regions the break-even splits. They are not figures, but they are copy, and
copy the server owns is copy that follows ``locale`` — the argument
``payoff_markers`` already makes for the marker labels. A client constant
would be an English word this project has no way to translate.

Pure, like the rest of the package: the profit range arrives from the domain's
own points and nothing here reads a clock or a repository.
"""

from decimal import Decimal
from typing import Final

from pydantic import BaseModel, ConfigDict, Field

from app.domain.payoff import PayoffCurve
from app.presentation.fragments import MoneyDisplay
from app.presentation.payoff_figures import Shape, amount

LOSS_LABEL: Final[str] = "Loss"
GAIN_LABEL: Final[str] = "Gain"

#: How many rungs the ladder aims for. The artboard draws five; the step
#: search below may land on four or six, which is what "aims for" means.
TARGET_RUNGS: Final[int] = 5

#: The mantissas a readable step is allowed to take, smallest first. The same
#: set `finance_charts`' `niceStep` uses on the client for the price axis —
#: written twice because the two axes are decided on opposite sides of the
#: wire, and asserted equal by neither, which `frontend/0034` OD-2 records.
_STEPS: Final[tuple[Decimal, ...]] = (
    Decimal(1),
    Decimal(2),
    Decimal(5),
    Decimal(10),
)


class PayoffZones(BaseModel):
    """What each side of the break-even is called."""

    model_config = ConfigDict(frozen=True)

    loss: str = Field(
        max_length=24,
        description="The word shown in the region below break-even.",
        examples=[LOSS_LABEL],
    )
    gain: str = Field(
        max_length=24,
        description="The word shown in the region above break-even.",
        examples=[GAIN_LABEL],
    )


def zones() -> PayoffZones:
    """Return the two region words, written here so they follow ``locale``."""
    return PayoffZones(loss=LOSS_LABEL, gain=GAIN_LABEL)


def _step(span: Decimal) -> Decimal:
    """Return a readable distance between two rungs covering ``span``.

    Args:
        span: The profit range the ladder has to cover; always positive.

    Returns:
        A power of ten times 1, 2, 5 or 10 — the smallest such value that
        does not put more than ``TARGET_RUNGS`` rungs on the axis.

    The loop deliberately stops one short of ``_STEPS``: ``magnitude`` is the
    largest power of ten at or below ``rough``, so ``rough`` is always under
    ten of them and the last mantissa cannot fail. Testing it anyway would be
    a branch no input can take, which coverage would then report for ever.
    """
    rough = span / TARGET_RUNGS
    magnitude = Decimal(10) ** rough.log10().to_integral_value(rounding="ROUND_FLOOR")
    for mantissa in _STEPS[:-1]:
        if mantissa * magnitude >= rough:
            return mantissa * magnitude
    return _STEPS[-1] * magnitude


def ticks(curve: PayoffCurve, shape: Shape) -> tuple[Decimal, ...]:
    """Return the profit values the axis draws a rule at, ascending.

    Zero is always one of them: it is the line the whole chart is read
    against, and a ladder that skipped it would leave the break-even rule
    unlabelled.

    Args:
        curve: The priced order, straight from the domain.
        shape: Unused for the arithmetic; kept in the signature so a caller
            cannot format the result some other way by accident.

    Returns:
        Between one and ``TARGET_RUNGS + 2`` values, including zero. One only
        for a curve that never moves, which is a zero-quantity order —
        ``PayoffCurve`` guarantees at least three points, so there is no
        empty case to answer for.
    """
    del shape
    values = [point.profit_loss for point in curve.points]
    low, high = min(min(values), Decimal(0)), max(max(values), Decimal(0))
    if low == high:
        return (low,)
    step = _step(high - low)
    first = (low / step).to_integral_value(rounding="ROUND_CEILING") * step
    rungs: list[Decimal] = []
    rung = first
    while rung <= high:
        rungs.append(rung)
        rung += step
    return tuple(rungs)


def value_axis(curve: PayoffCurve, shape: Shape) -> tuple[MoneyDisplay, ...]:
    """Return each rung as the ADR-E pair the client places and prints."""
    return tuple(amount(rung, shape) for rung in ticks(curve, shape))


__all__ = [
    "GAIN_LABEL",
    "LOSS_LABEL",
    "TARGET_RUNGS",
    "PayoffZones",
    "ticks",
    "value_axis",
    "zones",
]
