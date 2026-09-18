# ADR-E — Money representation and rounding

- **Status:** **Proposed** — awaiting TL ratification
- **Gates:** GGU-5
- **Related:** [ADR-F](ADR-F-persistence-and-session-lifetime.md)

## Context

> **In the context of** a finance demo whose credibility rests on numbers that tie out under a
> reviewer's arithmetic, **facing** an existing codebase that does float arithmetic and float
> formatting while the domain model proposes `Decimal`, **we decided** to use `Decimal` for all
> monetary and quantity values in the portfolio domain and convert only at the presentation
> boundary, **and neglected** (i) float throughout and (ii) integer minor-units, **to achieve** exact
> reproducible cost-basis and P/L arithmetic, **accepting that** the existing market-data path stays
> float until migrated.

## Decision

- **D-1** All monetary amounts, quantities, prices and cost bases in `portfolio.py` are `decimal.Decimal`. Float MUST NOT appear in the portfolio domain.
- **D-2** Single conversion boundary: `Decimal` → display string happens in one formatting module. Tools return `Decimal`; only the surface-emission layer formats.
- **D-3** Rounding: USD to 2 dp, crypto quantities to 8 dp, percentages to 2 dp, `ROUND_HALF_EVEN`. Rounding happens **only** at display, never in intermediate arithmetic.
- **D-4** Invariants tolerate no epsilon: `holding.quantity == Σ lot.quantity` and `cost_basis == Σ lot.cost_basis` are **exact** `Decimal` equalities. The weights-sum invariant is the sole permitted tolerance (`abs(Σw − 1) <= Decimal("0.0001")`).
- **D-5** `crypto_data.json` prices are parsed to `Decimal` **from the JSON string**, never via `float`, so `market_value = quantity × price` reconciles with what the market-data tool displays. A holding and the asset list showing different prices for BTC in one demo is the most reviewer-visible bug available.
- **D-6** The existing float path is **not** migrated in Epic 0, but MUST NOT compute any number the portfolio also computes. The buy-order quantity math is flagged for migration when Epic 1 owns order simulation.
- **D-7** Because [ADR-F](ADR-F-persistence-and-session-lifetime.md) D-3 stores the portfolio as a **live object**, no JSON codec for `Decimal` is needed today. If that decision is ever reversed, `Decimal` MUST serialize as a **string** — round-tripping through `float` reintroduces exactly the drift this ADR exists to prevent.

## Consequences

Two money representations coexist during Epic 0 (portfolio `Decimal`, market data float). D-5 and
D-6 are what keep them from disagreeing in front of a reviewer.
