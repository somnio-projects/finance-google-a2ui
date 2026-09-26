"""What ``compare_lot_methods`` accepts (spec 0052).

One position, one size, and the **list** of lot-selection methods to cost it
under. That list is the only structural difference from ``simulate_sale``,
which is why the two share ``sale_size.SaleSizeArguments`` and differ here.

Two fields the model is deliberately **not** given:

* **a tax rate.** The card prints the rate it costed with, because this demo
  knows no taxpayer and a rate nobody chose would be a tax claim nobody could
  check (GGU-134). Letting the model pick one would make the printed
  assumption model-authored, which is the same defect one layer up. The
  projection's declared defaults apply, and the card says so.
* **a winner.** ``presentation.scenario_verdict`` decides which column wins
  each row and the card writes its own summary sentence. A second ranking
  here would be two declarations of one fact — and ``app.agent`` may not
  import ``app.presentation`` in any case.
"""

from typing import Final

from pydantic import Field, field_validator

from app.agent.tools.sale_size import Method, SaleSizeArguments
from app.domain.lot_selection import LotMethod

#: One column per method the domain offers, derived from the enum exactly as
#: ``presentation.scenario_options.MAX_SCENARIOS`` is: a fourth method raises
#: both caps in the commit that adds it, never in a different one.
MAX_METHODS: Final[int] = len(LotMethod)

#: Every method, in the domain's own order — what the card shows when the
#: model names none, because "compare the methods" means all of them.
DEFAULT_METHODS: Final[tuple[Method, ...]] = tuple(method.value for method in LotMethod)


class CompareMethodsArguments(SaleSizeArguments):
    """Declared arguments of ``compare_lot_methods``; nothing else is accepted."""

    methods: tuple[Method, ...] = Field(
        default=DEFAULT_METHODS,
        min_length=2,
        max_length=MAX_METHODS,
        description=(
            "Lot-selection methods to compare, in the order they are shown. "
            "At least two, all distinct — two identical columns would claim a "
            "difference that does not exist. Omit for all of them."
        ),
        examples=[["FIFO", "HIFO"]],
    )
    include_wait: bool = Field(
        default=False,
        description=(
            "Add a 'Wait for long-term' column: the same sale past every "
            "lot's first anniversary, so all of it is long-term. It varies "
            "the timing, not the lot ordering, and it holds the price still."
        ),
        examples=[True],
    )

    @field_validator("methods")
    @classmethod
    def _distinct(cls, value: tuple[Method, ...]) -> tuple[Method, ...]:
        """Reject a repeated method rather than silently deduplicating it."""
        if len(set(value)) != len(value):
            msg = "methods must be distinct"
            raise ValueError(msg)
        return value

    def selections(self) -> tuple[LotMethod, ...]:
        """Return the requested methods as the domain's own enum, in order."""
        return tuple(LotMethod(method) for method in self.methods)


__all__ = ["DEFAULT_METHODS", "MAX_METHODS", "CompareMethodsArguments"]
