# 0037 — The agent reaches the catalog, or says why not

- **Area:** backend (agent host ↔ projection registry)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [backend/0036](0036-the-turn-is-fast-honest-and-observable.md) (the turn's telemetry, which is how this became visible), [backend/0011](0011-holdings-tool.md) OD-1, [backend/0035](0035-the-portfolio-has-an-owner-and-the-tabs-really-filter.md) (owns two of the four gaps), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) D-15, [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-3
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

A projection can be written, registered, 100 %-covered, published to
`/v1/views`, printed in the frozen contract and bound by a Flutter
component — and remain **impossible for the agent to compose**, because a
render intent is attached by a *tool* and no tool names it. Nothing in the
gate noticed.

Measured on 2026-09-22: **11 views registered, 5 reachable.**

Two of the day's symptoms were this, and neither looked like it:

- *"Show me my biggest winners and losers"* answered in prose. `holdings.positions.v1` exists and is unreachable; `get_holdings_summary` sorts by `gainers`/`losers` and deliberately suppresses the allocation donut for a return-ordered answer (0011 OD-1), so nothing takes its place.
- *"Compare keeping NVDA against trimming it by a third"* drew a **tax-lot table**. `scenario.comparison.v1` is the component for that question; it is unreachable, so the model reached for the nearest thing it could actually get.

This is GGU-79's finding one level up. There, a component could be registered
and still not reachable from a **route**, and no test compared the router with
the registry. Here it is the **agent** that cannot reach it. Same shape, same
fix: compare the two surfaces, and make every absence a sentence somebody
wrote.

## 2. Rulings

- **OD-1 — the check asserts classification, not reachability.** Requiring
  every view to be agent-reachable would be wrong: a view a *screen* requests
  by `?view=` is legitimately not an *answer*. What must not happen is an
  **undeclared** gap. `tests/unit/agent/test_catalog_reach.py` splits the
  registry three ways — reachable, `CLIENT_ONLY`, `DECLARED_GAPS` — and a new
  view is red until its author picks one, exactly as
  `test_component_names.py` is red until design has named it.

- **OD-2 — reachability is read from the tool sources, not by running them.**
  A tool attaches its view through a module-level `VIEW` constant. Exercising
  every tool against a portfolio to see which intents appear would make the
  inventory depend on the **seed data**: a tool that only attaches its surface
  for a non-empty result would read as unreachable on an empty portfolio, and
  the check would change meaning when spec 0035 changes the seed.

- **OD-3 — both directions, and no double-counting.** A line naming a view
  that is not registered is a stale claim that reads as a decision, so it
  fails. A view that is both reachable and listed as a gap fails too: closing
  a gap means deleting its line, not leaving both true.

- **OD-4 — the five are named, not counted.** `test_the_agent_reaches_the_views_the_demo_depends_on`
  asserts the set literally. An assertion of the form "N of M are reachable"
  goes green when one view is added and another is lost, which is the failure
  mode of every count this repository has regretted.

- **OD-5 — the four gaps get owners here, and two of them are not mine.**
  `activity.timeline.v1` and `holdings.positions.v1` belong with spec
  `backend/0035`, which is making that data real and per-user; building tools
  over data another change is reshaping would collide for no gain.
  `scenario.comparison.v1` and `payoff.curve.v1` are **unowned**, and
  `scenario.comparison.v1` is the one a user has already asked for — it
  should be the next agent feature. Not built here: this change is the check
  that makes the gaps visible, and shipping a check together with four
  features would bury it.

## 3. Acceptance criteria

1. **AC-1** — a registered view that no tool attaches and no list names fails the suite, with a message naming the view and the two lists.
2. **AC-2** — a list entry naming an unregistered view fails.
3. **AC-3** — a view that is both reachable and listed fails.
4. **AC-4** — the reachable set is asserted by name.
5. **AC-5** — `cd backend && make gate` green.

## 4. Test plan

| AC | How |
|---|---|
| 1 | **mutation-checked** — `payoff.curve.v1`'s line deleted → `AssertionError: ['payoff.curve.v1'] are registered and the agent cannot compose them` |
| 2, 3 | assertions in the same file, over the registry |
| 4 | a literal set |

## 5. Out of scope

Closing any of the four gaps (OD-5). Each is a feature with its own surface,
its own tool arguments and its own tests; this spec buys the ability to see
them.
