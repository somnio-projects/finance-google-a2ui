"""The transaction ledger — what the demo portfolio did to get where it is."""

from datetime import date
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field

from app.domain.money import Money, Quantity
from app.domain.symbols import SYMBOL_PATTERN


class TransactionType(StrEnum):
    """What a ledger row did to the position."""

    BUY = "buy"
    SELL = "sell"


class Transaction(BaseModel):
    """One executed buy or sell in the simulated history."""

    model_config = ConfigDict(frozen=True)

    transaction_id: str = Field(
        min_length=3,
        max_length=32,
        description="Stable identifier; also the same-date sort tiebreak.",
    )
    occurred_on: date = Field(description="The day it executed (UTC).")
    kind: TransactionType = Field(description="Buy or sell.")
    symbol: str = Field(pattern=SYMBOL_PATTERN, description="Ticker of the asset.")
    quantity: Quantity = Field(gt=0, description="Units bought or sold.")
    price: Money = Field(gt=0, description="Execution price per unit, in USD.")
    amount: Money = Field(gt=0, description="``quantity * price``, in USD.")


__all__ = ["Transaction", "TransactionType"]
