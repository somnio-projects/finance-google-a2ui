"""Deterministic daily price history (spec 0003 §4, OD-1).

``sparkline7d`` is gone with the old sample and GGU-36's attribution window is
still unspecified, so this package generates **90 daily points** per symbol,
ending at ``as_of``.

**How the generator works, and why it can be widened without a reseed:** the
price of a symbol ``offset`` days before ``as_of`` is a pure function of
``(symbol, offset)`` — a SHA-256 digest of ``"<symbol>:<offset>"`` yields a
drift in basis points within ``±MAX_DRIFT_BP``, which is applied to the current
price and quantized to that price's own exponent. ``offset == 0`` is forced to
zero drift, so **the last point always equals ``price(symbol)`` exactly**.
Because a given calendar day's price does not depend on how wide a window was
asked for, GGU-36 can raise ``HISTORY_DAYS`` without changing a single existing
point and without reseeding the portfolio.

The quantization here produces the source datum itself; it is not the
intermediate rounding ADR-E D-3 forbids.
"""

from datetime import date, timedelta
from decimal import ROUND_HALF_EVEN, Decimal
from hashlib import sha256
from typing import Final

from app.domain.market import price_of
from app.domain.prices import PricePoint
from app.domain.symbols import normalize_symbol

HISTORY_DAYS: Final[int] = 90
MAX_DRIFT_BP: Final[int] = 900
BASIS_POINTS: Final[Decimal] = Decimal(10_000)


def drift_basis_points(symbol: str, *, offset: int) -> int:
    """Return the deterministic drift, in basis points, ``offset`` days back.

    Args:
        symbol: Canonical ticker.
        offset: Days before ``as_of``; ``0`` is ``as_of`` itself.

    Returns:
        A drift in ``[-MAX_DRIFT_BP, MAX_DRIFT_BP]``, always ``0`` at offset 0.
    """
    if offset == 0:
        return 0
    digest = sha256(f"{symbol}:{offset}".encode()).digest()
    span = 2 * MAX_DRIFT_BP + 1
    return int.from_bytes(digest[:4], "big") % span - MAX_DRIFT_BP


def price_on(symbol: str, *, offset: int) -> Decimal:
    """Return the generated price of ``symbol`` ``offset`` days before ``as_of``.

    Args:
        symbol: A ticker in any case.
        offset: Days before ``as_of``; ``0`` returns the current price exactly.

    Returns:
        The price for that day, at the current price's own scale.
    """
    current = price_of(symbol)
    drift = Decimal(drift_basis_points(normalize_symbol(symbol), offset=offset))
    moved = current * (BASIS_POINTS + drift) / BASIS_POINTS
    return moved.quantize(current, rounding=ROUND_HALF_EVEN)


def price_history(
    symbol: str, *, as_of: date, points: int = HISTORY_DAYS
) -> tuple[PricePoint, ...]:
    """Return ``points`` daily prices ending at ``as_of``, ascending by date.

    Args:
        symbol: A ticker in any case.
        as_of: The day the series ends on — its point is the current price.
        points: How many daily points to generate, most recent last.

    Returns:
        The series, oldest first; empty when ``points`` is zero.
    """
    canonical = normalize_symbol(symbol)
    return tuple(
        PricePoint(
            symbol=canonical,
            observed_on=as_of - timedelta(days=offset),
            price=price_on(canonical, offset=offset),
        )
        for offset in reversed(range(points))
    )


__all__ = [
    "BASIS_POINTS",
    "HISTORY_DAYS",
    "MAX_DRIFT_BP",
    "drift_basis_points",
    "price_history",
    "price_on",
]
