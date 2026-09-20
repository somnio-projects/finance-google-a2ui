# ADR-F — In-memory persistence and session lifetime

- **Status:** Accepted (TL, 2026-09-18) · **amended 2026-09-20 — D-4 superseded by D-7/D-8/D-9; the amendment is Proposed and awaits TL ratification**
- **Gates:** GGU-5, GGU-3, GGU-12, GGU-29
- **Related:** [ADR-A](ADR-A-session-identity.md), [ADR-E](ADR-E-money-representation.md), [ADR-K](ADR-K-response-shaping.md) D-20 · specs [`backend/0004`](../../specs/backend/0004-session-identity.md), [`backend/0020`](../../specs/backend/0020-portfolio-persistence.md), [`infra/0001`](../../specs/infra/0001-dev-environment.md) §11

> **The title is now historical.** Persistence is no longer in memory. The file
> name is kept so the citations scattered through `backend/src`, the specs and
> the diagrams keep resolving; renaming it is a separate, mechanical change and
> the TL's to order.

## Context

> **In the context of** a showcase demo with a curated simulated portfolio and no real accounts,
> **facing** the choice of where per-session domain state lives and how long it survives, **we
> decided** to hold everything in process memory, seeded fresh per session, with no durable store,
> **and neglected** SQLite, Firestore and an ADK `DatabaseSessionService`, **to achieve** zero
> persistence infrastructure, deterministic demos and per-session isolation by construction,
> **accepting that** an instance restart loses all state and the reviewer's portfolio silently
> resets.

## Decision

- **D-1** ~~No durable persistence in Epic 0. All ADK services stay `InMemory*`.~~ — **overtaken in fact.** Conversations and messages are PostgreSQL tables (GGU-46, spec `0004`), the portfolio is three more (spec `0020`), and there is no ADK: `google-adk` is not a dependency of `backend/pyproject.toml`, the sample it named having been deleted under [ADR-J](ADR-J-rest-api-and-a2a-surface.md).
- **D-2** ~~The portfolio is seeded on session open and dies with the session.~~ — **overtaken in fact.** It is seeded on first access per **subject** and outlives every session and every process (spec `0020` §5). See D-7.
- **D-3** **Amended 2026-09-18 (TL): the portfolio is stored as a live object**, not as `model_dump(mode="json")`.
  - All access goes through **`get_portfolio(tool_context) -> Portfolio`** and **`save_portfolio(tool_context, portfolio)`**. These are load-bearing, not stylistic: they are what keeps the decision reversible.
  - Epic 1's tool tickets (GGU-36–39) MUST NOT read `state["portfolio"]` directly. With a single choke point, adopting a persistent session service later is a two-function change instead of a rewrite.
  - `save_portfolio` is also the one place the ADK state delta is written, per [ADR-A](ADR-A-session-identity.md) D-4 — rather than relying on in-place mutation appearing to work because it is the same object in memory.
  - A typed accessor is required regardless: `state.get("portfolio")` returns `Any` and would propagate `Unknown` into every tool under pyright.
  - **Resolved 2026-09-20 — the bet paid.** The named functions are gone with the ADK sample; the choke point they were is now the `PortfolioProvider` Protocol (`domain/provider.py`), and swapping the in-memory implementation for `PersistentPortfolioProvider` was the two-implementation change this ruling predicted, not a rewrite. No tool reads state directly. The ruling is kept because *why the seam existed* is the reusable part.
- **D-4** ~~**Cloud Run runs with `min-instances=1, max-instances=1`** for the review window. In-memory session state and autoscaling are incompatible — a scaled-out follow-up turn routes to an instance with no session, and the failure is silent. GGU-3 states this in its deploy configuration.~~ — **superseded 2026-09-20 by D-7, D-8 and D-9.** No environment ever ran 1/1, and the state the ruling protected is no longer in process memory. See the amendment below.
- **D-5** ~~The reviewer's portfolio resets on a cold start.~~ — **overtaken in fact.** It survives a restart: the same `as_of`, lots and ledger are read back (spec `0020` AC-1). The deterministic seed is still what a *first* access produces, and re-seeding is now a deliberate act — delete the row (spec `0020` OD-4). GGU-12's verification stands, with the expected outcome inverted.
- **D-6** The `as_of` clock is fixed **at seed time** so short/long-term lot classification cannot flip mid-demo. **Clarified 2026-09-20:** it is fixed once per **subject, in the `portfolios` row**, rather than once per session in process state. The property is stronger, not weaker — it now holds across sessions, instances and restarts. `datetime.now()` still appears nowhere in `app.domain`.
- **D-7** **Cloud Run scales horizontally; `max-instances` is a capacity knob, not a correctness one.** Everything a follow-up turn needs is in PostgreSQL — conversations and messages since GGU-46 (`alembic/versions/20260919_0004_sessions.py`), and the portfolio's lots, ledger and `as_of` since spec `0020` (`20260920_0005_portfolios.py`). The unique constraint on `portfolios.subject` is the load-bearing part: two instances seeding the same new subject converge on one row, the loser catching the integrity error and re-reading. The committed values — production 1/4, staging 0/2, dev 1/2 derived in `infra/main.tf` — are therefore **the decision**, not a divergence from it.
- **D-8** **`min-instances = 1` stays, for an unrelated reason, and it is a cost decision.** The demo on 2026-09-28 is a person opening the app in front of an audience, and the first request after an idle period pays a container boot plus a Cloud SQL connection over the VPC. A warm instance bills continuously and is dev's largest line after the database; that is the trade, stated in `infra/main.tf`. It buys **latency, not correctness**. An environment that sets it to 0 is correct and slow, which is a bill decision and nobody's architectural concern. **Nothing may cite D-8 as a safety property** — that conflation is what made D-4 outlive its reason.
- **D-9** **Two in-process caches survive D-4 and are now approximations, not guarantees.** The fixed-window rate limiter (`api/middleware/rate_limit.py`) counts per process, so the effective budget across *N* instances is *N* × the configured limit; the feature-flag TTL cache (`services/feature_flag_cache.py`) means a flag flip reaches another instance only when its TTL expires. Both were silently bounded by D-4's `max-instances=1`. Neither is a correctness defect at demo scale — the limiter is a compensating control ([ADR-G](ADR-G-secret-handling.md) D-7) and the TTL window is short — but both are now **documented approximations**, and the rate limiter must not be cited as a hard ceiling. Spec `0001` OD-2 already names the Redis adapter as the fix "when `max-instances > 1`"; that threshold has been crossed, and the limiter is a small class precisely so the swap is contained.

## Amendment 2026-09-20 — what replaced the single-instance constraint

**Status:** Proposed. D-7, D-8 and D-9 are drafted against the code as it stands; ratifying them is
the TL's.

**What D-4 was protecting.** One fact: session and portfolio state lived in process memory, so a
follow-up turn routed to a second instance would find nothing, and would say so in a fluent sentence
rather than an error. Pinning the service to exactly one instance made that unreachable.

**What the Terraform has always said.** Not 1/1, in any environment, ever. `production.tfvars` sets
1/4 and `staging.tfvars` 0/2; since GGU-29 dev overrides neither and derives 1/2 from
`main.tf` (`coalesce(var.min_instances, 1)`, `coalesce(var.max_instances, local.ephemeral ? 2 : 4)`).
The divergence was noticed — `specs/infra/0001` §11 and three Jira comments — but a spec section and
a ticket comment are where a decision goes to be forgotten. It is written here because this is where
the next person's Claude will look.

**What removed D-4's reason,** in order:

1. **GGU-46 (spec `0004`)** moved conversations and messages into the `sessions` and `messages`
   tables, scoped by subject. A follow-up turn stopped depending on which process answered it.
2. **Spec `0020` (PR #37)** moved the portfolio — `portfolios`, `portfolio_lots`,
   `portfolio_transactions`, with `as_of` persisted and `subject` unique. Before it, two instances
   each seeded from their own `clock.now()`: one subject, two portfolios, two `as_of`.

**How the last one was found, which is the part worth keeping.** No *figure* differed between the
two instances — prices are static and the tax-term boundaries sat days away — so nothing looked
wrong. What differed was `as_of`, and the strong `ETag` derives from
*(resource version, view, options, `as_of`)* ([ADR-K](ADR-K-response-shaping.md) D-20). A
revalidation landing on the other instance missed and answered 200 where it should have answered
304. A caching decision surfaced a state-sharing bug that the numbers were hiding.

**What is deliberately *not* claimed.** That the service is now horizontally scalable in general.
It is scalable for **this** application's state, at demo scale, with D-9's two approximations named.
Session affinity is not configured and is not needed; it is also not a fallback, because the thing
it would paper over no longer exists.

**Still the TL's to ratify:** these rulings' status; whether D-1, D-2 and D-5 should be struck
outright rather than annotated, since the machinery they describe was deleted; whether the record
should be renamed away from "in-memory persistence"; and whether D-9's Redis-backed limiter is Epic
1 work or is accepted as-is for the demo.

## Consequences

D-3 traded the option of persistent sessions for simplicity and bought it back through a single
choke point. **The trade has now been called in and it held** — the portfolio became a database
aggregate by writing a second implementation of one Protocol. That is the durable lesson: the
accessor pair was not style, it was the price of keeping D-1 reversible, and D-1 was reversed inside
two days.

The cost of the amendment is that `min-instances = 1` now means something different from what it
meant on 2026-09-18, in the same words. D-8 exists so nobody re-derives the old reason from the
surviving number.
