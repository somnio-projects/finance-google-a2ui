# 0044 — The portfolio is crypto

- **Area:** backend (domain, seed, projections, prompt fragments) → the generated catalog → the client's catalog-driven tests and goldens
- **Status:** In progress
- **Ticket:** GGU-114
- **Supersedes:** [backend/0025](0025-the-design-portfolio.md) **OD-2** (which replaced a crypto universe with a US equities one). 0025 is otherwise unchanged and still owns the design reconciliation this spec keeps.
- **Also:** [backend/0003](0003-portfolio-domain.md) (the seed and its invariants), [backend/0013](0013-simulated-sale.md) (lot selection), [backend/0026](0026-the-home-shell.md) (the day change and the movers), [backend/0028](0028-holdings-and-activity.md) (the Activity tab), [backend/0031](0031-order-ticket-v2.md) (the draft order and its legs), [backend/0035](0035-the-portfolio-has-an-owner-and-the-tabs-really-filter.md) (the ledger, the filters, the seed job), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-24

## 1. Problem

The showcase's demo portfolio is a US equities portfolio: NVDA, AAPL, MSFT, VOO,
BND, a bond fund, a gold ETF and a dollar sweep. The demo on 2026-09-28 is a
**crypto** portfolio, so every figure on every surface is about the wrong
asset class, and so is every word the model is taught.

This is not a styling change. The numbers on screen come from
`app.domain.market_data` and `app.domain.seed_data`, and the sentences the
model reads come from the tool descriptions and the generated catalog. An
equities vocabulary reaches the screen in five distinct ways:

1. **the tickers and names** — in the seed, the ledger, every projection
   example, the catalog, and the client's fixtures;
2. **the taxonomy** — `AssetClass` is Equities / Bonds / Cash / Alternatives
   and `Sector` is Technology / Financials / Healthcare / Consumer / Energy,
   both of which are *declared, bounded options* the client sends back;
3. **the ledger's income kind** — `dividend`, which a token does not pay;
4. **the units** — an equity order is a whole number of shares, and
   `order.ticket.v2` enforces that in a pattern. One whole unit of BTC is more
   than a quarter of this portfolio, so *whole shares* does not merely read
   oddly, it makes the demo's own Flow C compose a leg of **zero**;
5. **the prose the model copies** — "whole shares", "semiconductors",
   "$1.62/sh", *"put about $10k into semiconductors"*.

**0025 OD-2 chose equities deliberately**, to match design pages this
repository still reconciles against, and its reasoning is not wrong — it is
superseded by a product decision. The part of it worth keeping is kept: see
OD-4.

## 2. Scope

**In.** `app.domain` (taxonomy, symbols, market reference, seed lots, seed
ledger, baskets, draft legs, day change, portfolio history); the declared
option vocabularies in `app.schemas` and `app.presentation`; the Activity
projection's income kind; every projection example and prompt fragment; the
`kind` column's width plus its Alembic revision; both generated catalog
artefacts; the client's catalog-driven tests, fixtures and goldens.

**Out.** Any new projection, endpoint or component. Any change to how a figure
is computed, formatted or rounded — ADR-E is untouched. The waterfall and
tax-lot **component sources** in `frontend/app/lib/components/`: GGU-115 and
GGU-116 are redesigning both against the UI kit, and this change has no
business editing them (see §7). Live prices (OD-3). Crypto tax law (OD-5).

## 3. Rulings

Each of OD-1…OD-4 was left open by the ticket and decided by **Lautaro on
2026-09-24**; each is **revertible by Pato**. OD-5…OD-9 were decided in the
course of the work and carry the same ownership.

- **OD-1 — the universe is eight assets: BTC, ETH, SOL, AVAX (layer 1), ARB
  (layer 2), USDC (stablecoin), AAVE (DeFi), LINK (infrastructure).** Eight is
  what gives the donut five distinct slices, the waterfall bars of both signs
  and the tax-lot table two terms. **AVAX is the eighth**, and it is a second
  layer 1 rather than a second layer 2 for a reason the second grouping makes
  visible: with only Bitcoin, Ethereum and Solana as chains, five of the five
  asset classes would sit in three ecosystems and the ecosystem fold would be
  a near-relabelling of the class fold (OD-2). AVAX also inherits TSLA's role —
  bought and fully sold, so the timeline shows a closed position the holdings
  list correctly does not carry, and it is the day's largest mover without
  being held.

  **The stablecoin is an asset class like any other.** `taxonomy.py` argued
  that cash is not a special case because modelling it as one would put a
  branch in every consumer of a holding; tokenising the balance changes
  nothing about that argument, so `AssetClass.CASH` became
  `AssetClass.STABLECOIN` and every consumer kept its shape.

- **OD-2 — the second grouping stays `sector` in the contract and becomes the
  chain ecosystem in the data.** An equity's *economic sector* says nothing
  about a token, and the crypto vocabulary a reader would reach for — L1, L2,
  DeFi, oracles, stablecoins — **is** the asset-class vocabulary, so reusing it
  would make `group_by=sector` a relabelling of `group_by=asset_class` and the
  option pointless. The second fold is therefore the **chain family** the asset
  settles on: Bitcoin, Ethereum, Solana, Avalanche. It is genuinely orthogonal
  — BTC, ETH, SOL and AVAX share one class and no ecosystem, while ARB, AAVE
  and LINK share Ethereum across three classes — and it is the crypto reading
  of what a sector is *for*: the correlated-exposure bucket.

  The **option value** is not renamed. `sector` is design's own schema word
  (`"groupBy": "assetClass | sector"`), the client binds it, and the catalog
  snapshot publishes it; renaming it in a data change would break three
  contracts for a synonym.

  `MarketAsset.sector` stays nullable and **USDC carries none**: a multi-chain
  stablecoin is natively issued on every chain above, so naming one would be a
  false denominator in the one place `taxonomy.py` warns about. The ecosystem
  fold therefore sums to less than the portfolio — exactly as the sector fold
  did when it covered equities only.

  **`is_fund` is removed** with the same reasoning applied in the other
  direction. It existed to keep a pooled vehicle out of *Top movers* (0026
  OD-4); a universe of eight single names has none, and a flag that is false in
  every row is a claim the data does not support. The mover filter now names
  its only real subject — a dollar-pegged token does not move.

- **OD-3 — prices are a static fixture, not a feed.** The catalog artefacts and
  the client goldens are re-rendered and diffed by the gate, so a live price
  would make the gate fail on a quiet market rather than on a defect, and
  would make two runs of the demo tell different stories. Same mechanism as
  before: a table of strings in `market_data.REFERENCE_ROWS`, parsed to
  `Decimal` (ADR-E D-5).

- **OD-4 — the portfolio keeps the design's total and all-time gain: the change
  is *what it holds*, not *what it is worth*.** `$482,915.20` at a cost of
  `$421,711.15`, so the headline is still **+$61,204.05 (+14.51 %)**. Those two
  figures are what `Holdings.dc.html` and `Catalog_HoldingsSummary.dc.html`
  state and what `frontend/packages/finance_charts/test/design_reference.dart`
  encodes as the design's own numbers; spec 0025 solved the seed against them
  and there is no reason to spend that again. The seed is solved to hit both
  **exactly**, and `test_seed_ledger.py` asserts the total as a literal.

  What is **not** preserved is the day change: it is a function of the new
  prices, and it is now **+$2,201.05 (+0.46 %)**. Preserving it as well would
  have required 4-decimal previous closes chosen to hit a figure nothing
  depends on.

  **Every position's market value is cent-exact**, for both today and
  yesterday, so the displayed column still adds to the displayed total. That
  constrains quantities to three decimals at these prices, which is why the
  seed does not carry an 8-decimal quantity — see OD-5.

- **OD-5 — "day change" is a rolling 24 h window, computed on the backend and
  served formatted.** Crypto has no market close, so close-to-close has no
  meaning. The mechanism is unchanged and already correct: `previous_close` is
  a second *price* in the reference, `domain/day_change.py` is the single place
  the arithmetic happens, and the client receives `day` as a `*Display` string
  (rule N-2). What changed is what the field **means**, and it is documented as
  the price 24 hours ago rather than at a close. No code change was required,
  which is itself the finding: the design already avoided the assumption.

- **OD-6 — fractional units reach the order ticket, and a stepper's step is a
  property of the asset.** `order.ticket.v1`'s `size` already accepted eight
  decimals and needed nothing. `order.ticket.v2`'s `legs` accepted
  `TICKER:SHARES` as integers only, and `basket_legs` floored to a whole unit —
  which at $64,250 floors a $4,000 leg to **zero**. `legs` now carries the same
  digit shape `size` publishes (nine integers, eight decimals), spelled once
  and compared by a test.

  A ±1 stepper is equally wrong: one tap would move a leg by $64,250 and take a
  $9,773 draft past the portfolio's cash. `MarketAsset.step` is therefore a
  declared column of the reference — 0.01 for BTC, 0.1 for ETH, 1 for SOL, 100
  for ARB — and `stepped()` reads it. The client still never computes: each
  rendered leg carries the whole option value a `+` or `-` sends, as it did
  before (0031 OD-3). Baskets floor to the step for the same reason, so a leg
  is always on the grid its stepper moves along.

- **OD-7 — `dividend` becomes `staking_reward`; the kind is not relabelled, it
  is replaced.** A token pays no dividend. Relabelling the chip while the
  payload still said `kind: "dividend"` would put a false word in the contract,
  which is the one thing a declared option value may not be. A reward is paid
  **in the asset**, so it carries the units received as `quantity` and that
  day's unit price as `price`, and `amount == quantity * price` still holds for
  every kind. BTC pays none — proof of work has nothing to stake — and neither
  does USDC, because a yield this showcase does not model is not one it should
  claim.

  This is the one change that needs a **migration**: `portfolio_transactions.kind`
  was `String(8)`, sized when `dividend` was exactly eight characters.

- **OD-8 — Flow C's basket is `majors` (BTC 40 / ETH 35 / SOL 25).** The
  design's prompt is *"put about $10k into semiconductors, keep it diversified"*
  with three legs at 40/35/25. `majors` is the crypto reading that maps onto
  the same three legs at the same weights, so the design's own card still
  describes what the tool composes. The non-curated basket names become the
  ecosystems, split equally across what settles on each chain.

- **OD-9 — the seed is regenerated, not migrated, because every row in this
  database is demo data by construction.** No backfill of `'dividend'` to
  `'staking_reward'` is written: it would preserve rows whose symbols are no
  longer in the market reference, which is a worse state than having none. See
  §6.

## 4. Acceptance criteria

| # | Criterion | Where it is proven |
|---|---|---|
| AC-1 | No equity ticker remains in fixtures, seeds, catalog examples or prompt fragments | grep, pasted in the PR; `docs/catalog/*` regenerated |
| AC-2 | Quantities are fractional and eight decimals survive domain → projection → display → persistence | `test_display.py`, `test_simulate_sale_sizes.py` (`0.15564202` end to end), `EXACT = Numeric(38, 18)`, `test_portfolio_repository.py` |
| AC-3 | The donut, the waterfall and the tax-lot table all have real volume: five class slices, bars of both signs, a short **and** a long lot at a gain | `test_allocation_rows.py`, `test_attribution_headline.py`, `test_taxlot_render.py` |
| AC-4 | The model is taught crypto, not equities: tool descriptions, option descriptions and the generated fragments | `test_prompt.py`, `test_payoff_curve_options.py`, `docs/catalog/CONTRACT.md` |
| AC-5 | The income kind is a staking reward, in the option value, the chip, the badge and the row's words | `test_activity_timeline.py`, `view_options_tabs.ActivityKind` |
| AC-6 | The ledger persists: `kind` is wide enough for the new value, by a new revision | `20260924_0009_transaction_kind_width.py`, `test_portfolio_repository.py` |
| AC-7 | Flow C composes a buyable draft — no leg floors to zero — and its ticket is editable at a sane step | `test_baskets.py`, `test_draft_legs.py`, `test_order_ticket_v2*.py` |

## 5. Test plan

| Area | Suite | What it holds |
|---|---|---|
| Seed reconciliation | `tests/unit/domain/test_seed_ledger.py` | `buys - sells == the open lot`, to the unit and the cent; the ledger's kind counts; the total as a literal (OD-4) |
| Seed anchors | `tests/unit/domain/test_allocation.py` | the five class subtotals as literals, summing to `$482,915.20` |
| Day change | `tests/unit/domain/test_day_change.py` | `+$2,201.05`, and the three movers in order with the stablecoin excluded |
| Fractional units | `tests/unit/agent/tools/test_simulate_sale_sizes.py` | `$10,000 / $64,250` to eight places, and a **sub-dollar** price shown at four (ARB) — a case that was dead under equities |
| Lot selection | `tests/unit/presentation/test_scenario_comparison.py` | FIFO, LIFO and HIFO reaching three different figures on BTC's two lots |
| The stepper | `tests/unit/domain/test_draft_legs.py` | each asset's own step, and `None` at both bounds |
| Baskets | `tests/unit/domain/test_baskets.py` | `majors` at $10k composing `BTC:0.06,ETH:1.0,SOL:16`, compared against `DEFAULT_LEGS` rather than trusted |
| Contract | `tests/unit/presentation/test_catalog_snapshot.py`, `test_catalog_doc.py` | both artefacts re-rendered and diffed |
| Persistence | `tests/integration/test_portfolio_repository.py` | the seed round-trips through PostgreSQL at full scale |
| Client | `frontend/app/test/**` | the catalog-snapshot-driven component tests, and the goldens |

**Test decision.** No new test *file* is added: the change is data, and the
suites above already assert the figures as literals, which is what makes a data
change visible. Three tests were made **sharper** rather than merely updated,
and each is a case the equities seed could not reach:

1. `test_simulate_sale_sizes.py` had a comment recording that its sub-dollar
   case was dead because nothing in an equities portfolio is quoted below a
   dollar. ARB is, so the case is live again with real data.
2. `test_draft_order.py`'s refusal table used an invalid basket in every row, so
   the "amount is zero" row was rejected for its *basket* and the amount
   validator was never reached. Three of the four rows now carry a valid
   basket.
3. `test_draft_weights.py` asserted one weight-shift row; the design's three
   legs now settle on three chains, so it asserts three.

## 6. The staging re-seed

**The seed is re-applied and the old demo rows are replaced.** There is no
data-preserving migration and none is wanted (OD-9).

The mechanism already exists and needs no new code —
`app.jobs.seed_portfolios`, written for spec 0035 §4.1, whose `--reset` flag is
documented as *"the opposite instruction, said out loud: replace what is there
with a freshly seeded copy at today's `as_of`"*. It calls
`PortfolioRepository.replace`, which deletes the owner's lots and ledger and
writes the new ones.

So, in order:

1. `alembic upgrade head` — revision `0009` widens
   `portfolio_transactions.kind` to `String(16)`. Without it every insert of a
   `staking_reward` row fails, so this must land **before** the re-seed.
2. `python -m app.jobs.seed_portfolios --reset <the demo audience>` — as a
   Cloud Run job, with the addresses as `--args`. The job reports counts and
   never logs an address (spec 0035 §5).
3. Anyone the list misses is still correct on their next read:
   `PersistentPortfolioProvider` seeds on a miss, and a *new* owner gets the
   crypto seed with no intervention at all. Only owners who already have a row
   need the reset, which is what `--reset` is for.

## 7. Merge order

Two branches are in flight over the components this change's data feeds:
`feat/GGU-115_waterfall_matches_the_ui_kit` and
`feat/GGU-116_taxlot_table_matches_the_ui_kit`. Lautaro accepted the collision.

This change **edits no file** under
`frontend/app/lib/components/attribution_waterfall/**` or
`frontend/app/lib/components/taxlots_table/**`. It does regenerate their
goldens, because the data behind them changed. Expect this branch to need a
rebase and a second golden regeneration once those two land, and take theirs
for the component sources.

## 8. Out of scope

- **Crypto tax law.** The 12-month cut is applied unchanged and no wash-sale
  rule is modelled. The surfaces already say so, in words a reader sees:
  `scenarios.NOTES` prints *"before any tax rate, fee or wash-sale rule"* and
  `taxlots_guidance.py` teaches the model the same. The ticket expected a
  `disclosure` field on `taxlots.table.v1`; there is none, and none was added —
  the statement already exists one field over, and inventing crypto tax rules
  is not what this showcase demonstrates.
- **Staking mechanics.** Rewards are ledger rows. They do not create lots, do
  not compound and do not move the settlement balance — the same documented
  simplification dividends carried (0035 OD-8).
- **A wallet model.** No addresses, no chains-as-accounts, no gas. The
  portfolio is a set of positions, as before.
- **The `is_fund` column's replacement.** Nothing in the universe is a pooled
  vehicle, so the concept is gone rather than re-homed (OD-2). A future
  exchange-traded product would reintroduce it as a reference column.
