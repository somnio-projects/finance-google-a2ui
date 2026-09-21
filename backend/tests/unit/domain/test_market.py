"""AC-6 — the curated market reference is the one source of price."""

from decimal import Decimal

import pytest

from app.core.display import PRICE_PRECISION
from app.core.locales import quantize
from app.domain.errors import SymbolNotFoundError
from app.domain.market import MARKET_REFERENCE, market_asset, price_of
from app.domain.symbols import normalize_symbol


@pytest.mark.parametrize(
    "written",
    ["BTC", "btc", "  btc  ", "Btc"],
    ids=["upper", "lower", "padded", "mixed"],
)
def test_market_asset_is_symbol_normalised(written: str) -> None:
    assert market_asset(written).symbol == "BTC"


def test_market_asset_of_an_unknown_symbol_raises_with_the_symbol() -> None:
    with pytest.raises(SymbolNotFoundError, match=r"'NOPE' is not in the market"):
        market_asset("nope")


def test_price_of_is_an_exact_decimal_parsed_from_the_string() -> None:
    price = price_of("DOGE")
    assert isinstance(price, Decimal)
    assert price == Decimal("0.1273")
    assert str(price) == "0.1273"


def test_every_reference_entry_is_unique_and_priced() -> None:
    symbols = [asset.symbol for asset in MARKET_REFERENCE]
    assert len(symbols) == len(set(symbols))
    assert all(asset.price > 0 for asset in MARKET_REFERENCE)
    assert all(asset.logo_url.endswith(".svg") for asset in MARKET_REFERENCE)


def test_normalize_symbol_is_idempotent() -> None:
    assert normalize_symbol(normalize_symbol(" eth ")) == "ETH"


def test_every_reference_price_fits_the_display_precision() -> None:
    """Spec 0013 OD-4 — ``price_display`` promises the price ties out exactly.

    It carries ``PRICE_PRECISION`` places, so a reference quoting finer than
    that would silently break the multiplication a reader does between the
    price and the quantity beside it. Adding such an asset fails here, where
    the fix is to widen the constant, rather than in a demo.
    """
    for asset in MARKET_REFERENCE:
        assert asset.price == quantize(asset.price, precision=PRICE_PRECISION)
