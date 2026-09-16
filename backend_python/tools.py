# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import logging
import os
from typing import Optional

from google.adk.tools.tool_context import ToolContext

logger = logging.getLogger(__name__)

DATA_FILE = os.path.join(os.path.dirname(__file__), "crypto_data.json")
DATA_BASE_URL = "http://localhost:10002"

SORT_OPTIONS = ("market_cap", "gainers", "losers")


def format_usd(value: float) -> str:
    return f"${value:,.2f}" if value >= 1 else f"${value:,.4f}"


def format_compact_usd(value: float) -> str:
    for threshold, suffix in ((1e12, "T"), (1e9, "B"), (1e6, "M")):
        if value >= threshold:
            return f"${value / threshold:,.2f}{suffix}"
    return format_usd(value)


def format_pct(value: float) -> str:
    return f"{value:+.2f}%"


def format_quantity(value: float) -> str:
    return f"{value:,.4f}" if value >= 1 else f"{value:.8f}"


def _with_display_fields(asset: dict) -> dict:
    """Adds pre-formatted strings so the LLM copies them instead of formatting numbers."""
    return {
        **asset,
        "priceDisplay": format_usd(asset["price"]),
        "change24hDisplay": format_pct(asset["change24hPct"]),
        "trend": "up" if asset["change24hPct"] >= 0 else "down",
        "marketCapDisplay": format_compact_usd(asset["marketCap"]),
        "volume24hDisplay": format_compact_usd(asset["volume24h"]),
        "high24hDisplay": format_usd(asset["high24h"]),
        "low24hDisplay": format_usd(asset["low24h"]),
    }


def load_assets(base_url: Optional[str] = None) -> list[dict]:
    """Loads the fake market data, ordered by market cap rank."""
    with open(DATA_FILE, encoding="utf-8") as f:
        data_str = f.read()
    if base_url:
        data_str = data_str.replace(DATA_BASE_URL, base_url)
    return [_with_display_fields(asset) for asset in json.loads(data_str)]


def find_asset(symbol: str, base_url: Optional[str] = None) -> Optional[dict]:
    symbol = symbol.strip().upper()
    return next((a for a in load_assets(base_url) if a["symbol"] == symbol), None)


def get_crypto_assets(
        tool_context: ToolContext,
        category: Optional[str] = None,
        symbols: Optional[list[str]] = None,
        sort_by: str = "market_cap",
        count: int = 5,
) -> str:
    """Call this tool to get cryptocurrency market data.
    'category' optionally filters by category: Layer 1, Layer 2, DeFi, Meme,
    Payments, Exchange, Oracle, Interoperability.
    'symbols' optionally limits the result to specific tickers, e.g. ["BTC", "ETH"].
    'sort_by' is one of: market_cap (default), gainers, losers.
    'count' is the number of assets to return.
    """
    logger.info(f"--- TOOL CALLED: get_crypto_assets (count: {count}) ---")
    logger.info(f"  - Category: {category}")
    logger.info(f"  - Symbols: {symbols}")
    logger.info(f"  - Sort by: {sort_by}")

    try:
        items = load_assets(tool_context.state.get("base_url"))
    except (FileNotFoundError, json.JSONDecodeError) as e:
        logger.error(f"  - Error: Failed to load {DATA_FILE}: {e}")
        return json.dumps([])

    if category:
        items = [a for a in items if a["category"].lower() == category.strip().lower()]
    if symbols:
        wanted = {s.strip().upper() for s in symbols}
        items = [a for a in items if a["symbol"] in wanted]

    if sort_by == "gainers":
        items.sort(key=lambda a: a["change24hPct"], reverse=True)
    elif sort_by == "losers":
        items.sort(key=lambda a: a["change24hPct"])
    elif sort_by != "market_cap":
        logger.warning(f"  - Unknown sort_by '{sort_by}', using market_cap.")

    result = items[:count]
    logger.info(f"  - Success: Matched {len(items)} assets, returning {len(result)}.")
    return json.dumps(result)
