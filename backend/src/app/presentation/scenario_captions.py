"""The short line under each column head (spec 0051).

Its own module, and the reason is a cycle: ``scenario_build`` renders a column
and needs the caption, while ``scenario_after_tax`` needs ``signed_money``
from ``scenario_build``. One of the two facts has to live apart from both.
"""

from typing import Final

from app.domain.lot_selection import LotMethod

#: How the frame introduces each ordering, in its own words.
CAPTIONS: Final[dict[LotMethod, str]] = {
    LotMethod.FIFO: "default order",
    LotMethod.LIFO: "newest first",
    LotMethod.HIFO: "tax-optimized",
}

__all__ = ["CAPTIONS"]
