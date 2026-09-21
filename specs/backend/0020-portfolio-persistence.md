# 0020 — The portfolio lives in PostgreSQL

- **Status:** Approved (TL, 2026-09-20)
- **Ticket:** GGU-29 follow-up · **Supersedes:** spec `0003` OD-6 (in-memory provider)
- **Related:** [ADR-F](../../docs/adr/ADR-F-persistence-and-session-lifetime.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md), `0003-portfolio-domain.md`

## 1. Problem

The portfolio is built in process memory and cached in a `dict` keyed by
subject (`domain/provider.py::InMemoryPortfolioProvider`). Nothing about it is
persisted: the tables are `audit_events`, `feature_flags`, `sessions` and
`messages`, and there is no `portfolios` table to seed.

That was a deliberate decision (spec `0003` OD-6) taken when the service ran as
a single instance. **It stopped being safe on 2026-09-20**, when dev moved to
`min_instances = 1, max_instances = 2` so the demo would not pay a cold start.
Two instances now hold two independent caches, each seeded from its own
`clock.now()`, so one subject has two portfolios with two different `as_of`.

ADR-F **D-4** already required `min-instances=1, max-instances=1` for exactly
this reason. Rather than give up the warm instance the demo needs, this spec
removes the reason the constraint existed.

**What actually breaks today**, stated honestly — prices are static and the
tax-term boundaries sit days away from the seeded dates, so no *figure* changes
between instances:

- `as_of` differs, and it is rendered.
- The strong `ETag` is derived from `(resource version, view, options, as_of)`
  (ADR-K D-20), so a revalidation that lands on the other instance misses and
  answers 200 instead of 304.
- Nothing survives a restart, so a deploy silently re-seeds every subject.

## 2. Scope

**In.** A `portfolios` aggregate in PostgreSQL — the portfolio row, its open
tax lots and its transaction ledger. A repository, a persistent
`PortfolioProvider`, the migration, and the wiring change the session-per-request
rule forces.

**Out.** The market reference (`domain/market.py`) stays in code: it is
reference data, not user data, and one source of price is the point of
OD-5 in spec `0003`. Price history stays generated. No new endpoint — the
portfolio is read through the routes that already read it.

## 3. What is persisted, and what is deliberately not

`Portfolio` carries `as_of`, `positions`, `lots` and `ledger`. **`positions`
is derived from `lots`** — spec `0003` says the aggregates are derived "so the
seed cannot disagree with itself", and `Portfolio.validate` proves the
derivation still holds.

So `positions` is **not** persisted. Storing it would create exactly the
disagreement the derivation exists to prevent: a holdings row and its lots,
saved at two different moments, drifting apart with nothing to catch it. The
repository rebuilds positions from lots on read, and `validate` runs.

| Table | Columns | Why |
|---|---|---|
| `portfolios` | `id`, `subject` (unique), `as_of`, `created_at`, `updated_at` | one per subject; `as_of` is the fact that was being lost |
| `portfolio_lots` | `id`, `portfolio_id`, `lot_id`, `symbol`, `acquired_on`, `quantity`, `cost_basis`, `created_at` | the open lots, the tax story |
| `portfolio_transactions` | `id`, `portfolio_id`, `transaction_id`, `occurred_on`, `kind`, `symbol`, `quantity`, `price`, `created_at` | the ledger |

Money and quantity are `Numeric(38, 18)`, never float (ADR-E D-5). A `Decimal`
that round-trips through a float is a wrong number that looks right.

## 4. Two design consequences, both forced

**4.1 — `PortfolioProvider.get` becomes `async`.** A database read is
asynchronous and the Protocol is synchronous today. Every caller is already
`async` (`Tool.run`, `ViewService`), so this is four `await`s and a Protocol
signature, not a refactor.

**4.2 — the provider is built per request, not per process.** `Container` holds
`portfolio: PortfolioProvider` as a process-wide singleton. A repository needs
the request's `AsyncSession` (`architecture.md`: one session per request,
commit/rollback owned by `session_scope`), so a process-wide provider holding a
session would outlive it.

`Container.portfolio` is therefore **removed** and the provider is constructed
in `api/deps/`, which the rules already name as "the only place services are
constructed per request". Both consumers already receive it through `deps`
(`get_tool_context`, `ViewService(provider=...)`), so no consumer changes shape.

## 5. Seeding

`get(subject)` reads; on a miss it seeds from `domain/seed.py` at
`clock.now()`, saves, and returns. Spec `0003` OD-7 stands: *a demo session
must never open on an error*.

The race between two instances seeding the same new subject is resolved by the
**unique constraint on `subject`**: the loser catches the integrity error and
re-reads. It cannot invent a second portfolio, which is the property that was
missing before.

`as_of` is now fixed **once, in the database**, rather than once per process.

## 6. Acceptance criteria

1. **AC-1** — A subject's portfolio survives a process restart: the same
   `as_of`, lots and ledger are read back.
2. **AC-2** — Two providers over the same database return the same `as_of` for
   the same subject — the multi-instance divergence, asserted directly.
3. **AC-3** — `positions` is absent from the schema and rebuilt on read;
   `Portfolio.validate` passes on every load.
4. **AC-4** — Money and quantity round-trip exactly: a `Decimal` written is the
   `Decimal` read, to the last place.
5. **AC-5** — First access seeds and persists; the second access issues no
   insert.
6. **AC-6** — Two concurrent first accesses for one subject produce **one**
   portfolio row, not two.
7. **AC-7** — A subject reads only its own portfolio; a repository query is
   always scoped by subject.
8. **AC-8** — `make gate` green at 100 % branch coverage.

## 7. Test plan

**Unit** (`tests/unit/`): the provider against a fake repository — seed on
miss, no seed on hit, the integrity-error re-read path, and `as_of` taken from
the row rather than the clock when the row exists.

**Integration** (`tests/integration/`, real PostgreSQL): AC-1 through AC-7.
AC-6 runs two `get` calls concurrently with `asyncio.gather` over two sessions.
AC-4 asserts the exact `Decimal`, not `pytest.approx` — approximate money is
the bug this project exists to avoid.

**Mutation checks:** drop the unique constraint on `subject` → AC-6 red. Persist
`positions` instead of deriving → AC-3 red.

## 8. Security

The portfolio is user financial data. It is scoped by `subject` on every query
(AC-7); no symbol, quantity or figure is logged (`security.md`); the seeding
event keeps carrying `as_of` and the symbol set but never the subject, exactly
as it does today.

## 9. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | Async Protocol vs a sync façade over a cache | TL | **Async.** A sync façade means a cache, and the cache is what this spec removes. |
| OD-2 | Per-request provider vs a session-less singleton | TL | **Per-request**, per the session-per-request rule. `Container.portfolio` is removed rather than left holding something it must not hold. |
| OD-3 | Keep the in-memory provider for tests | TL | **Yes**, renamed and kept as a test double — unit tests must not need PostgreSQL. It stops being the production path. |
| OD-4 | Re-seed on deploy, or keep what is stored | TL | **Keep.** A deploy that silently rewrites the demo portfolio is the surprise this spec exists to end. Re-seeding is a deliberate act: delete the row. |
| OD-5 | Does this restore ADR-F D-4? | TL | It **removes D-4's reason**. ~~The ADR still says `min=1, max=1` and is still marked Accepted; amending it is a separate change, already flagged in `specs/infra/0001` §11.~~ **Done 2026-09-20:** that separate change landed — D-4 is superseded by [ADR-F](../../docs/adr/ADR-F-persistence-and-session-lifetime.md) D-7 (scaling out is a capacity decision), D-8 (`min-instances = 1` survives as a *cost* decision for the demo) and D-9 (the two in-process caches D-4 was silently bounding). The amendment is Proposed until the TL ratifies it. |
