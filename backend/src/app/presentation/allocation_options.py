"""What ``holdings.allocation.v1`` may be asked for (spec 0005, 0026 OD-2).

Its own module for the reason ``payoff_order.py`` is: the options grew a
domain object of their own (``group_by``) and the view is a projection, not a
place to keep a growing form. ``GroupBy`` lives beside the rows it selects.
"""

from pydantic import Field

from app.presentation.allocation_rows import GroupBy
from app.presentation.options import DisplayOptions, SortOptions, TopNOptions


class HoldingsAllocationOptions(DisplayOptions, SortOptions, TopNOptions):
    """Declared knobs of ``holdings.allocation.v1``; nothing else is accepted."""

    group_by: GroupBy = Field(
        default="holding",
        description=(
            "How the donut is sliced. `holding` is one slice per position; "
            "`asset_class` folds them into Equities, Bonds, Cash and "
            "Alternatives; `sector` folds the equities by sector."
        ),
        examples=["asset_class"],
    )
    headline: bool = Field(
        default=True,
        description=(
            "Carry the total and all-time gain block. The Home card draws the "
            "donut under the shell's own hero, so it asks for `false`."
        ),
        examples=[True],
    )


__all__ = ["HoldingsAllocationOptions"]
