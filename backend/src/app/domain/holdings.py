"""Holdings — one aggregated position per symbol (spec 0003 §4).

Every field is a stored ``Decimal`` rather than a property, because the
invariants in ``app.domain.invariants`` exist precisely to prove that the
stored aggregate still agrees with the lots it was built from.
"""

from pydantic import BaseModel, ConfigDict, Field

from app.domain.money import Money, Quantity
from app.domain.symbols import SYMBOL_PATTERN


class Holding(BaseModel):
    """An aggregated position: the sum of a symbol's open tax lots."""

    model_config = ConfigDict(frozen=True)

    symbol: str = Field(pattern=SYMBOL_PATTERN, description="Ticker of the asset.")
    name: str = Field(
        min_length=1, max_length=64, description="Display name of the asset."
    )
    quantity: Quantity = Field(gt=0, description="Units held across all open lots.")
    price: Money = Field(gt=0, description="Current price from the market reference.")
    market_value: Money = Field(gt=0, description="``quantity * price``, in USD.")
    cost_basis: Money = Field(ge=0, description="Sum of the open lots' cost bases.")
    unrealized_pl: Money = Field(
        description="``market_value - cost_basis``; negative for a loser."
    )
    weight: Money = Field(
        ge=0, le=1, description="Share of the portfolio's market value, 0 to 1."
    )


__all__ = ["Holding"]
