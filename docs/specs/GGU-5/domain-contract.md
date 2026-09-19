# Domain contract — portfolio model

- **Ticket:** [GGU-5](https://somniosoftware.atlassian.net/browse/GGU-5) · consumed by Epic 1 tools (GGU-36–39)
- **Status:** Draft for review · **Anchor:** `main` @ `410bb9d`
- **Governing records:** [ADR-E](../../adr/ADR-E-money-representation.md) · [ADR-F](../../adr/ADR-F-persistence-and-session-lifetime.md) · [ADR-A](../../adr/ADR-A-session-identity.md)

> This is a **module** contract, not an api-contract — GGU-5 exposes no HTTP surface. It exists
> because Epic 1's four tool tickets cannot start without these signatures.

## 1. Read surface

All money and quantity values are `Decimal` (ADR-E D-1). Arguments are keyword-only.

| Signature | Notes |
|---|---|
| `holdings() -> list[Holding]` | **Stable ordering across calls** — no set/dict-iteration nondeterminism |
| `tax_lots(symbol: str) -> list[TaxLot]` | Case/whitespace-insensitive symbol; unknown symbol → `[]`, never `KeyError` |
| `transactions() -> list[Transaction]` | Sorted descending by date, with a stable tiebreak for same-date rows |
| `price(symbol: str) -> Decimal` | Parsed from the market-data JSON **string**, never via `float` (ADR-E D-5) |
| `price_series(symbol: str, window: timedelta) -> list[PricePoint]` | See §4 — the window is unresolved |

## 2. Session-state accessor

Per ADR-F D-3 the portfolio is stored as a **live object**, and **all** access goes through:

```python
def get_portfolio(tool_context) -> Portfolio: ...
def save_portfolio(tool_context, portfolio: Portfolio) -> None: ...
```

**Epic 1's tools MUST NOT read `state["portfolio"]` directly.** This pair is what keeps ADR-F D-3
reversible: with one choke point, adopting a persistent session service later is a two-function
change rather than a rewrite. `save_portfolio` is also the single place the ADK state delta is
written (ADR-A D-4), rather than relying on in-place mutation working by accident.

Specify: what `get_portfolio` raises when the slot is absent.

## 3. Invariants

Exact `Decimal` equality, no epsilon (ADR-E D-4):

- `holding.quantity == Σ open lot.quantity`
- `holding.cost_basis == Σ lot.cost_basis`
- `holding.market_value == holding.quantity × price(symbol)`
- `abs(Σ weights − 1) <= Decimal("0.0001")` — the sole permitted tolerance

`validate()` must be able to **fail**: a hand-built portfolio violating each invariant raises with a
message naming the holding. A passing seed proves nothing if `validate()` can never reject.

## 4. Open — blocks seed curation

**Price-history depth.** `sparkline7d` gives 7 points; the attribution tool (GGU-36, Epic 1) needs a
window that is not yet specified. GGU-5 cannot curate a seed against an unknown consumer contract.
**Resolve with GGU-36's owner before GGU-5 starts.** Also define `price_series` behaviour when the
window exceeds available history (truncate vs raise) and when `window=0`.

## 5. Seed properties (load-bearing for the demo)

The seed must contain, and a test must assert:

- ≥1 lot within ±5 days of the 1-year short/long-term boundary;
- ≥1 holding with positive and ≥1 with negative unrealized P/L;
- ≥1 holding with ≥2 lots of differing term;
- every seeded symbol present in the market-data file, at the **same** price (ADR-E D-5) — otherwise
  the portfolio and the asset list show different prices for BTC in one demo.

Without these assertions the seed silently drifts into a portfolio that demos nothing.

## 6. Clock

`as_of` is fixed **per session at seed time** and stored in session state (ADR-F D-6), so a lot near
the 1-year boundary cannot flip term mid-demo. A future `as_of` in a lot is a validation error.

## 7. Layering constraint

Per ADR-C D-6, `portfolio.py` MUST NOT import from the agent, executor or entry-point modules. This
preserves the extraction seam for the deferred layering work at zero cost today.
