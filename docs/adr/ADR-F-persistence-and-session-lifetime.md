# ADR-F — In-memory persistence and session lifetime

- **Status:** Accepted (TL, 2026-09-18)
- **Gates:** GGU-5, GGU-3, GGU-12
- **Related:** [ADR-A](ADR-A-session-identity.md), [ADR-E](ADR-E-money-representation.md)

## Context

> **In the context of** a showcase demo with a curated simulated portfolio and no real accounts,
> **facing** the choice of where per-session domain state lives and how long it survives, **we
> decided** to hold everything in process memory, seeded fresh per session, with no durable store,
> **and neglected** SQLite, Firestore and an ADK `DatabaseSessionService`, **to achieve** zero
> persistence infrastructure, deterministic demos and per-session isolation by construction,
> **accepting that** an instance restart loses all state and the reviewer's portfolio silently
> resets.

## Decision

- **D-1** No durable persistence in Epic 0. All ADK services stay `InMemory*`.
- **D-2** The portfolio is seeded on session open and dies with the session.
- **D-3** **Amended 2026-09-18 (TL): the portfolio is stored as a live object**, not as `model_dump(mode="json")`.
  - All access goes through **`get_portfolio(tool_context) -> Portfolio`** and **`save_portfolio(tool_context, portfolio)`**. These are load-bearing, not stylistic: they are what keeps the decision reversible.
  - Epic 1's tool tickets (GGU-36–39) MUST NOT read `state["portfolio"]` directly. With a single choke point, adopting a persistent session service later is a two-function change instead of a rewrite.
  - `save_portfolio` is also the one place the ADK state delta is written, per [ADR-A](ADR-A-session-identity.md) D-4 — rather than relying on in-place mutation appearing to work because it is the same object in memory.
  - A typed accessor is required regardless: `state.get("portfolio")` returns `Any` and would propagate `Unknown` into every tool under pyright.
- **D-4** **Cloud Run runs with `min-instances=1, max-instances=1`** for the review window. In-memory session state and autoscaling are incompatible — a scaled-out follow-up turn routes to an instance with no session, and the failure is silent. GGU-3 states this in its deploy configuration.
- **D-5** The reviewer's portfolio resets on a cold start. The mitigation is that the seed is deterministic and curated, so a reset is always *coherent*. GGU-12 must **verify** this, not assume it.
- **D-6** The `as_of` clock is fixed **per session at seed time** and stored in session state, so short/long-term lot classification cannot flip mid-demo.

## Consequences

D-3 trades the option of persistent sessions for simplicity, and buys the option back through the
accessor pair. If Epic 1 bypasses the accessors, the trade is lost and the decision hardens into a
rewrite — this is the thing to watch in tool-ticket review.
