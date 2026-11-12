# 0055 — The order chip names a basket the agent supports

**Status:** In progress · **Ticket:** GGU-160 · **Area:** `backend/` (copy and test); the two Flutter suites that assert the chip text follow

## 1. Problem

The third Home chip, "Build a $10k order in tech", is the entry to Flow C, but
`draft_order` accepts only `majors` and the four chain ecosystems. "Tech" is a
leftover from the equities era (GGU-114); the agent answered in prose that the
basket was unsupported instead of drawing an order ticket.

## 2. Scope

**In:** the chip reads "Build a $10k order in the majors" (BTC/ETH/SOL at
40/35/25, so the ticket shows three legs). `FLOW_C_BASKET` in
`presentation/summary_questions.py` is the single name, and a unit test holds
it inside `app.domain.baskets.Basket`. Regenerated: `docs/catalog/*`,
`docs/a2ui/v1.0/examples/*`; the chip literal in both `home_rail_test.dart`.
**Out:** teaching the agent a "tech" basket.

## 3. Acceptance criteria

- **AC-1** The Flow C chip's basket is one `draft_order` accepts and expands to more than one leg (unit test).
- **AC-2** The chip text names that basket, so copy and tool cannot drift (unit test).
- **AC-3** The three chips still cover Flows A, B and C (existing test, GGU-32).
