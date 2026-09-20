"""The persisted portfolio of one subject (spec 0020).

``subject`` is the ownership key and it is **unique**: one subject has exactly
one portfolio. That constraint is not decoration — it is what makes two
instances seeding the same new subject converge on one row instead of two
(spec 0020 AC-6), which is the whole reason this aggregate left process memory.

``as_of`` lives here rather than being read from a clock on each load. It was
the fact being lost when two processes each seeded their own copy: the figures
matched, but the moment they were taken did not, and the ``ETag`` derives from
it (ADR-K D-20).

**What is deliberately absent: holdings.** ``Portfolio.positions`` is derived
from the lots, and ``Portfolio.validate`` proves the derivation still holds
(spec 0003). Persisting it would let a holdings row and the lots it summarises
drift apart with nothing to catch it — the exact disagreement the derivation
exists to prevent. Positions are rebuilt on read.
"""

from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import Date, DateTime, ForeignKey, Numeric, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin

#: Money and quantity are stored exactly, never as a float (ADR-E D-5). The
#: scale is wide enough for a crypto quantity and a sub-cent price; a `Decimal`
#: that round-trips through a float is a wrong number that looks right.
EXACT = Numeric(38, 18)


class Portfolio(TimestampMixin, Base):
    """One subject's portfolio, read back at the ``as_of`` it was seeded with."""

    __tablename__ = "portfolios"
    __table_args__ = (UniqueConstraint("subject", name="uq_portfolios_subject"),)

    subject: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    as_of: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class PortfolioLot(TimestampMixin, Base):
    """One open acquisition lot, cascading from its portfolio."""

    __tablename__ = "portfolio_lots"

    portfolio_id: Mapped[UUID] = mapped_column(
        ForeignKey("portfolios.id", ondelete="CASCADE"), nullable=False, index=True
    )
    lot_id: Mapped[str] = mapped_column(String(32), nullable=False)
    symbol: Mapped[str] = mapped_column(String(10), nullable=False)
    acquired_on: Mapped[date] = mapped_column(Date(), nullable=False)
    quantity: Mapped[Decimal] = mapped_column(EXACT, nullable=False)
    cost_basis: Mapped[Decimal] = mapped_column(EXACT, nullable=False)


class PortfolioTransaction(TimestampMixin, Base):
    """One executed buy or sell, cascading from its portfolio."""

    __tablename__ = "portfolio_transactions"

    portfolio_id: Mapped[UUID] = mapped_column(
        ForeignKey("portfolios.id", ondelete="CASCADE"), nullable=False, index=True
    )
    transaction_id: Mapped[str] = mapped_column(String(32), nullable=False)
    occurred_on: Mapped[date] = mapped_column(Date(), nullable=False)
    kind: Mapped[str] = mapped_column(String(8), nullable=False)
    symbol: Mapped[str] = mapped_column(String(10), nullable=False)
    quantity: Mapped[Decimal] = mapped_column(EXACT, nullable=False)
    price: Mapped[Decimal] = mapped_column(EXACT, nullable=False)
    amount: Mapped[Decimal] = mapped_column(EXACT, nullable=False)


__all__ = ["EXACT", "Portfolio", "PortfolioLot", "PortfolioTransaction"]
