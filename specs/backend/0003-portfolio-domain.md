# 0003 — In-memory portfolio domain (holdings, tax lots, transactions, pricing)

- **Area:** backend
- **Status:** Draft
- **Ticket:** GGU-5 · **Related specs / ADRs:** 0001, ADR-A, ADR-C, ADR-E, ADR-F · module contract `docs/specs/GGU-5/domain-contract.md`
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

The whole point of the showcase is that the portfolio lives in the backend and
deterministic tools compute over it — the LLM never does arithmetic. Today the
backend has no portfolio: no holdings, no tax lots, no transactions, no price
history. Epic 1's four tool tickets (GGU-36/37/38/39) cannot start without
these signatures, and GGU-12 and Epic 3's flows consume the same data.

The Jira ticket was written against the old `backend_python/` sample, which was
deleted: there is no `crypto_data.json`, no ADK `tool_context` and no
`session_state` in this repository. This spec re-baselines GGU-5 onto the
current `backend/` FastAPI service (layered `api → services → repositories →
models`, `src/app`, 100 % branch coverage, basedpyright strict, ≤150 lines per
file) and resolves the consequences of that deletion in §3 and §8.

The data is deliberately fake, but it must be **internally consistent**: wrong
or incoherent numbers are the first thing a technical reviewer checks in a
finance demo, and a portfolio that shows one price for BTC while the asset list
shows another is the most visible bug available in this project.

## 2. Scope

**In:**

- A new framework-free package `backend/src/app/domain/` with pydantic
  entities (`Holding`, `TaxLot`, `Transaction`, `PricePoint`) and the
  `Portfolio` aggregate.
- Exact-`Decimal` invariant validation that can fail and names the offending
  holding.
- Lot-term derivation from an injected `as_of` (OD-4 boundary rule).
- A curated **market reference** (symbol, name, current price, logo URL) owned
  by this package — the single source of price for the backend, replacing the
  deleted `crypto_data.json`.
- A deterministic **90-day daily** price series per symbol whose last point is
  the symbol's current price (OD-1).
- A **code-defined** seed (OD-2) with the three demo cases asserted by tests.
- A `PortfolioProvider` Protocol plus an in-memory implementation — the only
  access path to a subject's portfolio.
- Backend README section naming the three demo cases with their symbols.

**Out:**

- Any HTTP surface. This ticket exposes **none** — see §3.
- The analytics themselves (`compute_attribution`, `simulate_sale`, `payoff`,
  `get_holdings`) — Epic 1, GGU-36/37/38/39; they consume this package.
- Session persistence and uid binding — **GGU-46**, which implements the same
  `PortfolioProvider` Protocol. No session code is touched here.
- Database persistence, Alembic migrations, repositories — the portfolio is an
  in-memory aggregate (ADR-F D-1).
- Real market data, real execution, order simulation.

## 3. API contract

**This ticket exposes no HTTP surface.** There is no route, no controller, no
`deps.py` provider and no `router.py` entry; `api/`, `bootstrap.py` and the
OpenAPI document are unchanged. What follows is the **module** contract Epic 1
codes against. All values are `Decimal`; rounding happens only at display
(ADR-E D-2, D-3), never in this package.

| Signature | Contract |
|---|---|
| `Portfolio.holdings() -> list[Holding]` | Stable ordering across calls — seed order, never set/dict iteration order |
| `Portfolio.tax_lots(symbol: str) -> list[TaxLot]` | Symbol normalised (case- and whitespace-insensitive); unknown symbol returns `[]`, never raises |
| `Portfolio.transactions() -> list[Transaction]` | Sorted descending by date; same-date rows tie-break ascending by `transaction_id` |
| `Portfolio.price(symbol: str) -> Decimal` | The market reference price for that symbol; unknown symbol raises `SymbolNotFoundError` (404-mapped) |
| `Portfolio.price_series(symbol, window: timedelta) -> list[PricePoint]` | Ascending by date, last point is the current price. See the window rules below |
| `Portfolio.validate() -> None` | Raises `PortfolioInvariantError` naming the offending holding; returns `None` when clean |
| `seed_portfolio(*, as_of: datetime) -> Portfolio` | Keyword-only, aware datetime required; deterministic for a given `as_of` |
| `PortfolioProvider.get(subject) / .save(subject, portfolio)` | The only access path (ADR-F D-3) |

**`price_series` window rules (OD-1 follow-up, resolved here):**

- The generated history is `HISTORY_DAYS = 90` daily points ending at `as_of`.
- `window` selects `min(window.days, HISTORY_DAYS - 1) + 1` points, so
  `window=timedelta(days=7)` returns 8 points (7 days back plus `as_of`).
- A window **wider than the history truncates** — it never raises and never
  fabricates points beyond the 90 days.
- `window=timedelta(0)` returns exactly **one** point: `as_of` at the current
  price.
- A **negative** window is a programming error and raises
  `WindowOutOfRangeError`.

**Error codes** (problem-details identifiers, for the day a controller exposes
them): `portfolio/unknown-symbol` → 404, `portfolio/invariant-violated` → 422,
`portfolio/invalid-window` → 422. They subclass `NotFoundError` and
`ValidationFailedError` from `app.core.errors`, so the existing RFC 9457
handler already renders them correctly when Epic 1 adds routes.

**Layering.** `app/domain/` is an inner, framework-free layer beside `core`: it
may import stdlib, pydantic and `app.core` only. It imports nothing from
`api`, `services`, `repositories`, `models`, `infra` or `auth` — the
`ADR-C D-6` extraction seam, expressed as a package instead of a single file.

## 4. Data model & migration

**No tables, no migration, no Alembic revision.** The portfolio is held in
process memory and seeded per subject (ADR-F D-1, D-2). Modules:

| Module | Holds |
|---|---|
| `domain/money.py` | `Money` / `Quantity` — `Decimal` annotated to **reject `float`** at the model boundary |
| `domain/errors.py` | `SymbolNotFoundError`, `PortfolioInvariantError`, `WindowOutOfRangeError` |
| `domain/terms.py` | `LotTerm`, `holding_period_days`, `derive_term` (the OD-4 rule) |
| `domain/lots.py` | `TaxLot` (`lot_id`, `symbol`, `acquired_on`, `quantity`, `cost_basis`) + derived `term`, `market_value`, `unrealized_pl` |
| `domain/holdings.py` | `Holding` (`symbol`, `name`, `quantity`, `price`, `market_value`, `cost_basis`, `unrealized_pl`, `weight`) |
| `domain/transactions.py` | `TransactionType`, `Transaction` |
| `domain/prices.py` | `PricePoint` |
| `domain/market.py` | `MarketAsset`, `MARKET_REFERENCE`, `normalize_symbol`, `market_asset`, `price_of` |
| `domain/history.py` | `HISTORY_DAYS`, `drift_basis_points`, `price_on`, `price_history` |
| `domain/invariants.py` | `WEIGHT_TOLERANCE`, `validate_holding`, `validate_weights` |
| `domain/portfolio.py` | the `Portfolio` aggregate and its read surface |
| `domain/seed_data.py` | the curated lot and transaction tables (strings only) |
| `domain/seed.py` | `seed_portfolio(*, as_of)` |
| `domain/provider.py` | `PortfolioProvider` Protocol + `InMemoryPortfolioProvider` |

**Term is derived, never stored.** `TaxLot` has no `term` column; `term(as_of)`
computes it, so a lot cannot carry a stale classification.

**`Portfolio` is a frozen dataclass**, not a pydantic model: its required read
method `validate()` would shadow pydantic's deprecated `BaseModel.validate`
classmethod. Its fields (`positions`, `lots`, `ledger`) are tuples of already
validated pydantic entities, and the field names differ from the method names
(`holdings()`, `tax_lots()`, `transactions()`) for the same reason.

**The price-series generator (OD-1).** The price for a symbol on a given day is
a pure function of `(symbol, offset)` where `offset` is the number of days
before `as_of`: a SHA-256 digest of `"{symbol}:{offset}"` yields a drift in
basis points within ±`MAX_DRIFT_BP`, applied to the current price and quantized
to the current price's own exponent. `offset == 0` is forced to zero drift, so
**the last point always equals `price(symbol)` exactly**. Because a calendar
day's price does not depend on the requested window, GGU-36 can widen
`HISTORY_DAYS` without reseeding and without changing any existing point.

## 5. Security notes

No endpoint, no credential handling, no user input parsing, no database, no
audit event. The data is entirely simulated: no real balances, no PII, no
market feed, no order execution. Still relevant:

- **Session isolation is a security property, not just correctness.**
  `InMemoryPortfolioProvider` keys portfolios by subject and never shares an
  object between subjects; the accessor pair is the single choke point so
  GGU-46 can swap in a uid-bound session store as a two-class change. GGU-46
  owns uid binding; this spec owns per-subject separation of the object.
- **The seed stays obviously fake** — no customer-like names, no plausible
  account identifiers, placeholder logo URLs on an `.example` host. A demo
  portfolio that reads like real records invites someone to treat it as such.
- **No PII in logs.** The provider logs once per seed with `as_of` and the
  symbol set — the two values that determine every number the demo shows, and
  without which a reported wrong number cannot be reproduced. The subject is
  **not** logged.
- **Invariant failures are actionable**: the message names the offending
  holding and both sides of the comparison. A failure that says only
  "validation failed" is useless against a multi-holding portfolio.

Maps to `backend/docs/SECURITY.md` — no new control is claimed, and no existing
one is weakened.

## 6. Acceptance criteria

1. **AC-1** A seeded portfolio built at a fixed injected `as_of` exposes
   holdings, tax lots, transactions and a price series, and `validate()`
   passes on it.
2. **AC-2** All invariants hold **exactly** (`Decimal` equality, no epsilon):
   `holding.quantity == Σ open lot quantity`, `holding.cost_basis == Σ lot cost
   basis`, `holding.market_value == holding.quantity × price(symbol)`. Portfolio
   weights sum to 1 within `Decimal("0.0001")` — the only tolerance.
   `validate()` **fails** on a hand-built portfolio violating each one, with a
   message naming the offending holding.
3. **AC-3** Lot term is derived from `acquired_on` against the injected
   `as_of`, never stored. The rule — long-term requires **strictly more than
   365 days** held — is documented in the module docstring and asserted at
   366d, the 365d boundary, 364d, 1d and same day, including the leap-year case
   (acquired 2024-02-29, `as_of` 2025-02-28 → 365 days → short). A future
   `acquired_on` raises.
4. **AC-4** Read methods are deterministic and stable across repeated calls:
   `holdings()` returns the same order twice; `tax_lots("BTC")`,
   `tax_lots("btc")` and `tax_lots(" btc ")` agree; an unknown symbol returns
   `[]` and never raises; `transactions()` is descending by date with an
   ascending `transaction_id` tiebreak on same-date rows.
5. **AC-5** Money is `Decimal` end to end, parsed from strings: a `float` fed
   into any money or quantity field is **rejected** with a `ValidationError`,
   and `domain/money.py` — the module that rejects it — is the only one in the
   package that mentions `float` at all.
6. **AC-6** Every seeded symbol exists in the curated market reference and each
   holding's `price` **equals** that reference's price — one source of price
   for the whole backend.
7. **AC-7** The seed provably contains: at least one lot within ±5 days of the
   1-year boundary; at least one holding with positive and at least one with
   negative unrealised P/L; at least one holding with 2+ lots of differing term.
8. **AC-8** All portfolio access goes through `PortfolioProvider.get` /
   `.save`. The in-memory implementation seeds on first access with the `as_of`
   taken from the injected `Clock`, fixed for that subject from then on, and
   two subjects get independent portfolios — a mutation saved for one is
   invisible to the other and both stay `validate()`-clean.
9. **AC-9** `datetime.now()` appears nowhere in `app/domain/`, and the package
   imports nothing from `api`, `services`, `repositories`, `models`, `infra` or
   `auth` — both enforced by a test that greps the package.
10. **AC-10** `price_series` truncates when the window exceeds the 90-day
    history, returns exactly one point for `window=0`, raises for a negative
    window, and its last point equals `price(symbol)` exactly.
11. **AC-11** The backend README documents the three per-flow interesting cases
    **with their symbols** (tax-lot flow, attribution story, order/payoff).
12. **AC-12** `make gate` stays green: ruff, basedpyright strict, the 150-line
    budget, `make quality`, pytest at 100 % branch coverage, pip-audit.

## 7. Test plan

All unit; this ticket has nothing to integrate with (no HTTP, no database), so
there is **no integration test** — the DB-backed suite is untouched.

| AC | Unit test(s) |
|---|---|
| AC-1 | `tests/unit/domain/test_seed.py::test_seed_portfolio_at_fixed_as_of_validates` |
| AC-2 | `tests/unit/domain/test_invariants.py::test_validate_holding_quantity_mismatch_names_the_holding`, `::test_validate_holding_cost_basis_mismatch_names_the_holding`, `::test_validate_holding_market_value_mismatch_names_the_holding`, `::test_validate_weights_outside_tolerance_is_rejected`, `::test_validate_weights_inside_tolerance_is_accepted`, `test_portfolio.py::test_portfolio_validate_rejects_a_future_lot` |
| AC-3 | `tests/unit/domain/test_terms.py::test_derive_term_classifies_holding_period` (parametrized with ids `366d-long`, `365d-boundary-short`, `364d-short`, `1d-short`, `same-day-short`, `leap-year-2024-02-29-to-2025-02-28-short`), `::test_holding_period_days_rejects_a_future_acquisition` |
| AC-4 | `tests/unit/domain/test_portfolio.py::test_holdings_returns_the_same_order_on_repeated_calls`, `::test_tax_lots_is_symbol_normalised`, `::test_tax_lots_of_an_unknown_symbol_is_empty`, `::test_transactions_are_descending_with_a_stable_same_date_tiebreak` |
| AC-5 | `tests/unit/domain/test_money.py::test_money_field_rejects_float`, `::test_money_field_accepts_string_int_and_decimal`, `test_package_boundaries.py::test_only_the_money_module_mentions_float` |
| AC-6 | `tests/unit/domain/test_seed.py::test_every_seeded_symbol_reconciles_with_the_market_reference` |
| AC-7 | `tests/unit/domain/test_seed.py::test_seed_contains_a_lot_near_the_one_year_boundary`, `::test_seed_contains_a_winner_and_a_loser`, `::test_seed_contains_a_holding_with_lots_of_differing_term` |
| AC-8 | `tests/unit/domain/test_provider.py::test_provider_seeds_on_first_access_and_is_stable`, `::test_two_subjects_get_independent_portfolios`, `::test_saved_portfolio_replaces_the_previous_one` |
| AC-9 | `tests/unit/domain/test_package_boundaries.py::test_domain_never_reads_the_wall_clock`, `::test_domain_has_no_outward_imports` |
| AC-10 | `tests/unit/domain/test_history.py` (window truncation, zero window, negative window, last point equals the current price, determinism) |
| AC-11 | reviewed in the PR (UAT-4); the README section is part of this PR |
| AC-12 | `make gate` |

Mutation checks required (auth / rate limit / error masking): **no** — this
ticket touches none of them. The equivalent mutation check here is AC-2's
negative cases: they are what prove `validate()` can fail, since a `validate()`
that returns unconditionally would pass the positive seed test forever.

**Guardrail carried from the ticket:** an exact `Decimal` equality is never
weakened into an epsilon comparison to make a test pass. A failing exact
equality is a real `float` leak and is fixed at the source.

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | Price-history depth (blocked on GGU-36's window contract) | TL | **Resolved:** deterministic 90-day daily series per symbol, last point equal to the current price; the generator is documented so GGU-36 can widen `HISTORY_DAYS` without reseeding |
| OD-2 | JSON seed vs code seed | TL | **Resolved:** code-defined seed in `domain/seed_data.py`; no loader, no second validation path |
| OD-3 | `as_of` clock ownership | TL | **Resolved:** injected and fixed at seed time (ADR-F D-6); `datetime.now()` appears nowhere in the package — the provider takes it from the `Clock` protocol |
| OD-4 | The 365-day boundary rule | TL | **Resolved:** long-term requires **strictly more than** 365 days; documented in `domain/terms.py` and asserted, leap year included |
| OD-5 | Market reference after `crypto_data.json` was deleted | TL | **Resolved:** this package owns a small curated reference and is the single source of price for the backend |
| OD-6 | The ADK `tool_context` accessor pair | TL | **Resolved:** there is no ADK; a `PortfolioProvider` Protocol (`get`/`save`) inside the package, with an in-memory implementation. GGU-46 implements the same Protocol for session persistence |
| OD-7 | `get` when the subject has no portfolio yet | Implementer | **Resolved:** it seeds one and remembers it, rather than raising — a demo session must never open on an error, and the `as_of` is then fixed for that subject |
| OD-8 | Logging library, against ADR-C D-7 (stdlib `logging` for Epic 0) | Implementer | **Divergence, recorded:** D-7 was written for the deleted `backend_python/` sample, where structlog was not configured. This backend configures structlog from `bootstrap`, so the provider uses `app.core.logging.get_logger`. Using stdlib `logging` here would be the inconsistency D-7 was trying to prevent |

## 9. Rollout & observability

Nothing ships behind a feature flag: the package is not reachable from any
route yet, so merging changes no runtime behaviour. The first consumer (Epic 1)
gates its own routes with `require_feature("portfolio.<capability>")`.

Observability is minimal by design — per-read logging would be noise at
tool-call frequency. `InMemoryPortfolioProvider` emits one
`portfolio.seeded` event per subject with `as_of` and the sorted symbol set,
and nothing else. Sentry expectations are unchanged: an invariant violation
raises `PortfolioInvariantError`, which is an `AppError` and therefore an
expected, reportable 422 rather than an unhandled exception.
