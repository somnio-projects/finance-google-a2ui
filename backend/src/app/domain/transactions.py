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
    STAKING_REWARD = "staking_reward"
    DEPOSIT = "deposit"


class Transaction(BaseModel):
    """One ledger row of the simulated history — a trade, a reward, a deposit.

    A staking reward is paid in the asset, so it carries the units received as
    ``quantity`` and that day's unit price as ``price``; a deposit is ``USDC``
    at a price of one, so ``amount == quantity * price`` holds for every kind
    and one invariant covers them all (spec 0044 OD-7).
    """

    model_config = ConfigDict(frozen=True)

    transaction_id: str = Field(
        min_length=3,
        max_length=32,
        description="Stable identifier; also the same-date sort tiebreak.",
    )
    occurred_on: date = Field(description="The day it executed (UTC).")
    kind: TransactionType = Field(description="What the row did.")
    symbol: str = Field(pattern=SYMBOL_PATTERN, description="Ticker of the asset.")
    quantity: Quantity = Field(gt=0, description="Units bought or sold.")
    price: Money = Field(gt=0, description="Execution price per unit, in USD.")
    amount: Money = Field(gt=0, description="``quantity * price``, in USD.")
    memo: str | None = Field(
        default=None,
        max_length=64,
        description="Words the timeline prints beside the row, server-written.",
        examples=["Bank transfer · Chase ••4021"],
    )


__all__ = ["Transaction", "TransactionType"]
