# 0031 — `order.ticket.v2`: the multi-leg draft order, with its impact

- **Area:** backend (+ frontend/0013 for the client half)
- **Status:** In progress
- **Ticket:** [GGU-108](https://somniosoftware.atlassian.net/browse/GGU-108)
- **Also:** [0018](0018-order-ticket-projection.md) (`order.ticket.v1`, untouched), [0022](0022-surface-actions.md) (why `onSubmit` is not built here), [0024](0024-contract-serves-the-designs.md) §3 (the ruling that made this a `v2`), [0025](0025-the-design-portfolio.md) (the equities seed this was blocked on), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md) · rule `.claude/rules/backend/presentation.md`
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

Flow C's artboards and `Catalog_OrderTicket.dc.html` draw one component:
*"three legs with stepper + weight controls, and a live Order-impact panel.
Variant (a) is the default draft; (b) is after the user bumps NVDA — total,
weights, shares and cash recompute, changed values highlighted in indigo"*;
the catalog page adds *"an over-cash validation error"*. `order.ticket.v1` is
a single-leg ticket and spec 0024 §3 ruled that the design's ticket is not a
backwards-compatible addition to it — it is a second contract, raised as
GGU-108 and marked post-demo.

**The product owner has asked for it before the demo, and the question it
was blocked on is answered.** 0024 OD-1 asked whether the showcase acquires an
equity slice with sectors, because the impact panel's *sector weight before →
after* cannot be computed over eight crypto assets. Spec 0025 shipped the
17-ticker equities portfolio with `asset_class` and `sector` on every
`MarketAsset`, so sector weights **are** computable — this spec records that
the block is lifted and builds on it.

Two invariants decide the shape. A projection is pure (ADR-K D-6), so the
stepper's edit must travel as a declared option and the impact must be
recomputed **here**, never in the client (N-2). And the design's stepper adds
one to a share count — arithmetic the client may not perform even once — so
the payload has to hand the client the value each tap sends.

## 2. What ships

- **`order.ticket.v2`** (component `MultiLegOrderTicket`, OD-1), served by the
  portfolio endpoints beside v1, which is **unchanged byte for byte** — its
  module, payload, snapshot entry and digest `d0daddcb8960` are the same.
- **Options** (`OrderTicketV2Options`, `DisplayOptions` + two): `legs`, one
  bounded string `NVDA:3,AVGO:2,AMD:14` (OD-2), and `side`, `buy | sell`. A
  ticker outside the reference or a leg named twice is the option's own 422
  (`legs`), on both callers' paths.
- **Payload** (`OrderTicketV2Payload`): `title` (`Draft order · Buy · 3 legs`),
  `badge` (`editable | blocked`), `side`, `legs` (the option echoed under its
  own name, so the contract reports it editable — 0019 OD-3), `lines[]` (each
  leg's `key`, `symbol`, `name`, `price`, `quantity`, `notional`, `weight` as
  ADR-E pairs, plus `increment` / `decrement`, OD-3), `impact` (`total`,
  `units`, `fees`, `cash_remaining` as labelled pairs, `weight_shifts[]` with
  `before → after`), `constraints` (`max_cash`, `breach`, `shortfall`,
  `message`, OD-4), `effect: "recalculate"`, `disclosure`.
- **Domain:** `draft_legs` (the `legs` grammar, read and written), `draft_impact`
  (what the order costs, buys and leaves), `draft_weights` (a group's weight
  before and after, OD-5), `baskets` (a vague theme into legs, OD-8).
- **Agent tool `draft_order`** — *"Put about $10k into semiconductors, keep
  it diversified"* → `amount="10000", basket="semiconductors"` → the legs the
  design draws, the impact pre-formatted, and a render intent for
  `order.ticket.v2` carrying the same `legs`, so the words and the surface
  describe one order (AC-7).
- **Guidance** from the page's Zone 3, with three recorded edits (OD-6).
- `ProjectionOptions` (the flat query model) gains `legs`; the catalog
  artefacts regenerate; `DESIGN_CATALOG`, `SHIPPED_VIEWS`, `DESIGNED` and
  `EXPECTED_TOOLS` each gain their line.

## 3. Rulings

- **OD-1 — the component is `MultiLegOrderTicket`; `OrderTicket` stays with
  v1.** Spec 0023 §3 names a component by its own Zone 2 block, and the block
  on `Catalog_OrderTicket.dc.html` *is* this multi-leg ticket — by the rule,
  v2 should be `OrderTicket`. But the ticket forbids moving v1 by a byte, two
  projections cannot share the one string the client registers against, and
  a rename of v1 is a client-breaking change with its own review. So v2 takes
  a distinct name that says what differs, `docs/catalog/design/README.md`
  records the design's name against it, and **re-pointing** — retiring or
  renaming v1 and giving v2 the design's name — is filed as the follow-up
  this spec does not do.
- **OD-2 — the legs are one bounded string, not one option per ticker.**
  `^[A-Z]{2,10}:[0-9]{1,6}(,[A-Z]{2,10}:[0-9]{1,6}){0,4}$`: one to five
  `TICKER:SHARES` pairs, whole shares. Seventeen optional `quantity_<key>`
  integers would make most combinations illegal states and spell the asset
  list into the options schema a second time (the reason `view_options`
  already gives for `symbol`); a JSON list cannot travel as a query
  parameter with a bound the prompt can print. Membership and distinctness
  are the parser's, raised as the option's `ValueError` so pydantic reports
  them under `legs`. The pattern is duplicated in `schemas/view_options.py`
  for the same reason `DECIMAL_PATTERN` is, and a test compares the copies.
- **OD-3 — the stepper is two option values the backend wrote.** The client
  may not add one to `3` (N-2), so each rendered leg carries `increment` and
  `decrement`: the whole `legs` string with that leg moved by one, composed
  by `draft_legs.stepped` from the same parser and bound the options model
  enforces. `null` at zero shares or at the six-digit ceiling means the
  control is disabled rather than sending a value the backend refuses. A
  test feeds every published stepper value back through `validated_options`.
- **OD-4 — the blocked state is declared, never compared.** `constraints`
  carries the bound (`max_cash`, the seeded `USD · Cash & sweep`), a `breach`
  enum (`none | over_cash`), the `shortfall` as an ADR-E pair and the
  sentence to show verbatim — *Exceeds available cash — reduce order by
  $15,366.98.* The client colours cash red because `breach` says so, not
  because it parsed a minus sign. The design's `perLegCapPct` is **not**
  published: nobody has set a per-leg cap, and a bound the backend does not
  enforce is the defect `testing.md` records three times. `badge` follows
  the breach, so the header pill is server-written too.
- **OD-5 — *Semis* is not a sector this taxonomy has.** The impact row reads
  *Portfolio weight · Technology*: an equity is reported under its **sector**,
  and a leg without one (a bond fund, gold, cash) under its **asset class**,
  so no leg is silently dropped from the panel. Adding a `semiconductors`
  sector would re-slice the allocation donut the design draws with six
  sectors (0025 OD-7). The figures are the portfolio's, as every number here
  is: Technology holds 46.57 % and the default draft moves it to 48.52 %,
  where the design's gallery data says 6.2 % → 8.3 %. Same ruling as 0025
  OD-7 — the component matches, the numbers derive.
- **OD-6 — the Zone 3 fragment is transcribed with three edits.** 0024 §5
  declined it whole for *"let the client recompute impact on edit"*; the
  guidance now says the backend recomputes it on every edit. *"the user
  submits via onSubmit; execution is simulated by the backend"* names an
  event and a capability this showcase does not have (0018 OD-2); the rule
  it protects — never place or confirm an order in prose — is kept, the
  mechanism dropped. The example intent is kept verbatim. Recorded in
  `order_ticket_v2_guidance.py` and in `docs/catalog/design/README.md`.
- **OD-7 — a sell is priced, never blocked.** It raises cash and moves the
  sector down by the same figure. Whether the shares exist to sell is
  `simulate_sale`'s question (0018 OD-3), and a ticket that checked it would
  give two surfaces two opinions about one sale (0014 OD-11).
- **OD-8 — baskets are a closed vocabulary, and shares are floored.**
  `semiconductors` is curated with the design's own weights (40 / 35 / 25 →
  NVDA / AVGO / AMD); every other basket is a sector of the taxonomy split
  equally across its single-name equities (a fund is a basket already).
  *"About ten thousand"* is a ceiling a reader trusts, so shares are
  floored — the design's `$10,000` becomes `$9,427.78` at the seeded prices
  — and a leg that floors to zero is kept at zero so the stepper can bring
  it in. The projection's default `legs` **is** this composition, and
  `test_baskets` compares the two.
- **OD-9 — `onSubmit` is deferred to a surface action.** 0022's one-line
  test: *if the answer is the same view with different numbers, it is an
  option* — a step is; a submission is not, and there is nothing to submit
  to. The payload declares no action, the props carry no submit, and the
  client draws the design's buttons as honest placeholders (frontend/0013
  OD-3). When a broker exists, `onSubmit` is a declared action with an
  enforced bound, not a field added here.

## 4. Test decision

Unit, every figure a literal over the seeded portfolio (0025): the `legs`
grammar both ways and at both bounds; the impact for a buy within cash, a buy
beyond it and a sell; the weight shift for one sector, two groups and an
empty portfolio; every basket resolving to reference members whose weights
sum to one, and the design prompt composing the default legs. The projection
over the default, blocked, sell, locale and zero-leg cases; every stepper
value accepted back through `validated_options`; six malformed `legs` values
refused as a 422 naming the option; the surface carrying no way to place an
order; the tool's payload, render intent, refusals and every basket. The
registry-wide suites — interactivity declarations, actionable props, prompt
bounds, component names across four artefacts, query options against the
live route — extend to the new view by walking the registry. Both catalog
artefacts regenerated and committed. Not run here: the manual run against
the docker stack, which the integration branch owns.
