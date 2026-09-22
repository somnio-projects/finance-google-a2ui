"""Owner-scoped access to the persisted portfolio (spec 0020, 0035).

Every query is scoped by ``owner`` — the caller's verified e-mail, lower-cased
(``Principal.owner_key``). A portfolio belonging to somebody else comes back as
``None`` — never as a row the caller is then trusted to reject (ADR-A D-2, the
same rule ``SessionRepository`` follows).

This module is the only place that knows the portfolio has rows at all. It
converts between the ORM and the pure domain aggregate in both directions, so
``domain/`` stays free of SQLAlchemy and ``services/`` stays free of both.
"""

from collections.abc import Sequence

from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from app.core.errors import DependencyUnavailableError
from app.domain.lots import TaxLot
from app.domain.portfolio import Portfolio as PortfolioAggregate
from app.domain.transactions import Transaction
from app.models.portfolio import Portfolio, PortfolioLot, PortfolioTransaction
from app.repositories.base import BaseRepository
from app.repositories.portfolio_rows import (
    lot_of,
    lot_row,
    positions_of,
    transaction_of,
    transaction_row,
)


class PortfolioRepository(BaseRepository[Portfolio]):
    """Read and replace one owner's portfolio."""

    model = Portfolio

    async def find(self, *, owner: str) -> PortfolioAggregate | None:
        """Return ``owner``'s portfolio, or ``None`` when they have none.

        Positions are **rebuilt** from the lots rather than read: the domain
        derives them and ``Portfolio.validate`` proves the derivation, so a
        stored copy could only ever disagree with its own lots (spec 0020 §3).

        Args:
            owner: The caller's ownership key (``Principal.owner_key``).

        Returns:
            The aggregate, or ``None`` when no row belongs to this owner.

        Raises:
            DependencyUnavailableError: If the database cannot be read.
        """
        row = await self._row_for(owner)
        if row is None:
            return None
        lots = await self._lots_of(row)
        ledger = await self._ledger_of(row)
        portfolio = PortfolioAggregate(
            as_of=row.as_of,
            positions=positions_of(lots),
            lots=lots,
            ledger=ledger,
        )
        portfolio.validate()
        return portfolio

    async def replace(self, *, owner: str, portfolio: PortfolioAggregate) -> None:
        """Store ``portfolio`` as ``owner``'s, replacing anything there.

        Args:
            owner: The caller's ownership key (``Principal.owner_key``).
            portfolio: The aggregate to persist.

        Raises:
            DependencyUnavailableError: If the database cannot be written.
            IntegrityError: If another writer created this owner's portfolio
                first. The caller re-reads rather than retrying the write —
                that is the race `uq_portfolios_owner_email` exists to decide.
        """
        existing = await self._row_for(owner)
        try:
            # A SAVEPOINT, not a bare write. PostgreSQL aborts the whole
            # transaction on an integrity violation, so a caller that loses the
            # race and then tries to read the winner's row would hit "current
            # transaction is aborted" instead — which is exactly what happened
            # the first time this ran against a real database. The nested
            # block rolls back only itself and leaves the outer transaction,
            # owned by `session_scope`, usable for that re-read.
            async with self._session.begin_nested():
                row = existing or Portfolio(owner_email=owner, as_of=portfolio.as_of)
                row.as_of = portfolio.as_of
                self._session.add(row)
                await self._session.flush()
                await self._clear_children(row)
                self._session.add_all(
                    [lot_row(row.id, lot) for lot in portfolio.lots]
                    + [transaction_row(row.id, tx) for tx in portfolio.ledger]
                )
                await self._session.flush()
        except IntegrityError:
            raise
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database write failed") from exc

    async def _row_for(self, owner: str) -> Portfolio | None:
        """Return the portfolio row owned by ``owner``, scoped by it."""
        try:
            result = await self._session.execute(
                select(Portfolio).where(Portfolio.owner_email == owner)
            )
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database read failed") from exc
        return result.scalar_one_or_none()

    async def _lots_of(self, row: Portfolio) -> tuple[TaxLot, ...]:
        """Return the open lots of ``row``, in a stable order."""
        rows = await self._children(PortfolioLot, row, PortfolioLot.lot_id)
        return tuple(lot_of(lot) for lot in rows)

    async def _ledger_of(self, row: Portfolio) -> tuple[Transaction, ...]:
        """Return the ledger of ``row``, ordered as the domain expects."""
        rows = await self._children(
            PortfolioTransaction, row, PortfolioTransaction.transaction_id
        )
        return tuple(transaction_of(tx) for tx in rows)

    async def _children[RowT](
        self, model: type[RowT], row: Portfolio, order_by: object
    ) -> Sequence[RowT]:
        """Return one portfolio's child rows in a deterministic order."""
        try:
            result = await self._session.execute(
                select(model)
                .where(model.portfolio_id == row.id)  # pyright: ignore[reportAttributeAccessIssue]
                .order_by(order_by)  # pyright: ignore[reportArgumentType]
            )
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database read failed") from exc
        return result.scalars().all()

    async def _clear_children(self, row: Portfolio) -> None:
        """Remove the lots and transactions of ``row`` before rewriting them."""
        for model in (PortfolioLot, PortfolioTransaction):
            await self._session.execute(
                delete(model).where(model.portfolio_id == row.id)
            )


__all__ = ["PortfolioRepository"]
