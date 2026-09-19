"""One observed price for one symbol on one day (spec 0003 §4)."""

from datetime import date

from pydantic import BaseModel, ConfigDict, Field

from app.domain.money import Money
from app.domain.symbols import SYMBOL_PATTERN


class PricePoint(BaseModel):
    """A single point of a symbol's daily price series."""

    model_config = ConfigDict(frozen=True)

    symbol: str = Field(pattern=SYMBOL_PATTERN, description="Ticker of the asset.")
    observed_on: date = Field(description="The day this price belongs to (UTC).")
    price: Money = Field(gt=0, description="Price in USD on that day.")


__all__ = ["PricePoint"]
