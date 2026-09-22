# 0035 — The portfolio has an owner, and the tabs really filter

- **Area:** backend (+ the client half in [`frontend/0018`](../frontend/0018-the-tabs-search-and-filter-for-real.md))
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here (see 0025 §6)_
- **Also:** 0003 (the domain seed), 0020 (portfolio persistence), 0027 (user provisioning), 0028 (the Holdings and Activity tabs), 0030 (the greeting names the caller), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md), [ADR-B](../../docs/adr/ADR-B-auth-credential-contract.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

Two complaints from the TL against the deployed dev app
(`https://finance-a2ui.web.app`), and one of them is not the complaint it
looks like.

**(a) "The filters and search are stubs."** Half true, and the half that is
false is the more interesting one. The Activity tab's chips *already* work
end to end: `activity.timeline.v1` declares a bounded `kind` option
(spec 0028), `ActivityBloc` sends it as a query parameter and
`activity_rows.groups_for` filters the ledger server-side. What does not
work is that **there is almost nothing to filter**. The seeded ledger holds
22 rows, of which **one** is a sell and **two** are deposits, so `Sells`
shows a single line and `Deposits` two — a control that is indistinguishable
from a broken one. Meanwhile the two app-bar icons on both tabs are honest
placeholders that raise *"Search is not part of this preview yet."* /
*"Filter is not part of this preview yet."*
(`frontend/app/lib/features/shell/view/tab_app_bar.dart`, recorded as
`specs/frontend/0009` OD-7), and `holdings.positions.v1` declares no filter
of any kind: the Holdings list is fetched with an empty option map.

**(b) "The portfolio data is global, not owned by anybody."** Also half
true, and the half that is true is worse than it sounds. `portfolios` is
keyed by `subject` — the identity provider's opaque `sub`. Every caller
does get their own row, so nothing is literally shared; but a row keyed
`gH7x…` names nobody, **the same person signing in through Firebase's Google
button and through its e-mail button owns two different portfolios**, and
there is no answer at all to the question *whose demo portfolio is this?*
The provisioning registry added by 0027 already decided that the join key
between an identity and this service is the **verified e-mail** (0027 OD-1),
and the portfolio never got the memo.

## 2. Scope

**In:**

- **Ownership by e-mail.** `portfolios.subject` becomes `portfolios.owner_email`
  (migration `0008`), and the key every read and write uses is
  `Principal.owner_key`.
- **A seed you can run by hand, for a list of people.**
  `python -m app.jobs.seed_portfolios <email> [<email> …] [--reset]`, plus the
  `seed-portfolios` Cloud Run job that runs it on dev. §4.1.
- **A ledger worth filtering.** The curated seed grows from 22 to 48 rows:
  16 buys, 7 sells, 16 dividends and 9 deposits, spread over 27 months, with
  gains and losses and both tax terms.
- **A `query` (search) option** on `activity.timeline.v1` and
  `holdings.positions.v1`, matched **server-side**.
- **An `asset_class` option** on `holdings.positions.v1`, with the chips —
  words and all — shipped in the payload the way Activity's already are.
- **A sentence for an empty result**, server-written, on both projections.
- **A term badge that does not call a loss a gain** (§6 OD-5).

**Out:**

- Seeding different *data* per owner. Every owner is seeded from the same
  curated portfolio; see OD-2.
- Pagination or a cursor over the ledger. `limit` (1..200) already bounds it
  and the seed is 48 rows.
- A filter on the Activity app bar. Its chips are the filter; see
  `frontend/0018` §3 OD-2.
- Any change to `users`, to the sign-in flow or to what `GET /v1/me/access`
  answers.
- **A dividend-income tool for the agent — a named gap, not an oversight
  (OD-11).**

## 3. API contract

No new route. Two existing operations gain declared, bounded options; both
are additive with defaults, so neither projection is versioned up (ADR-K:
an option with a default cannot break a caller that never sends it).

| Method & path | Auth | New query parameters | Response | Errors |
|---|---|---|---|---|
| `GET /v1/portfolios/{portfolio_id}/views` | Bearer | `query` (≤24 chars, `^[A-Za-z0-9 .&'-]{1,24}$`), `asset_class` (`all\|equities\|bonds\|alternatives\|cash`) | unchanged envelope | undeclared option or out-of-range value → `validation-failed → 422`; unknown view → `404` |
| `POST /v1/view-renders` | Bearer | the same two, inside each entry's `options` | unchanged | per-entry `422` |

### 3.1 `activity.timeline.v1`

```
ActivityOptions(DisplayOptions, SearchOptions):
    kind:  all | buy | sell | dividend | deposit   (unchanged, default all)
    limit: int 1..200                              (unchanged, default 100)
    query: str | None, max_length 24               (new, default None)
```

Payload gains two fields, both server-written words (N-9):

```
query: str | None   # the search this render honoured, echoed back
empty: str          # "No activity matches this filter." — shown when groups is ()
```

### 3.2 `holdings.positions.v1`

```
HoldingsPositionsOptions(DisplayOptions, SortOptions, SearchOptions):
    sort:        value_desc | value_asc | label    (unchanged)
    query:       str | None, max_length 24         (new)
    asset_class: all | equities | bonds | alternatives | cash   (new, default all)
```

Payload gains four fields:

```
asset_class: the filter this render honoured
query:       the search this render honoured
filters:     tuple[ClassFilter, ...]  # key + label, the chips, server-worded
empty:       str  # "No holdings match this filter."
```

`total` and `gain` stay the **whole portfolio's** — see OD-4.

### 3.3 What a search matches

`query` is matched case-insensitively as a **substring**, against fields the
domain already carries — never against a rendered string, so the result does
not change when a label does:

| Projection | Matched against |
|---|---|
| `activity.timeline.v1` | `Transaction.symbol`, `Transaction.memo` |
| `holdings.positions.v1` | `Holding.symbol`, `Holding.name` |

A blank or whitespace-only `query` is *no filter*, not a filter that matches
nothing. `kind`/`asset_class` and `query` compose with **and**.

## 4. Data model & migration

Alembic revision **`0008`** (`20260922_0008_portfolio_owner_email.py`,
revises `0007`):

```
portfolios
  - subject       varchar(255)  not null unique (uq_portfolios_subject)
  + owner_email   varchar(320)  not null unique (uq_portfolios_owner_email)
```

**Existing rows are deleted, on purpose, and the migration says so.** An
opaque `sub` cannot be mapped to an e-mail by any rule this service knows —
there is no join to attempt. The alternatives were to keep unreachable rows
(a table that grows with garbage nobody can read) or to invent a mapping
(a wrong owner is worse than no row). The data is simulated and reseeds on
the next read: `PersistentPortfolioProvider.get` seeds on a miss, which is
spec 0003 OD-7, and every screen already carries the words *"Simulated
activity — resets each session."* The downgrade drops the column and empties
the table for the same reason.

`ON DELETE CASCADE` on `portfolio_lots` and `portfolio_transactions` means
the delete is one statement.

No table is added. `users` is untouched: the portfolio does **not** carry a
foreign key to it, because a provisioned e-mail and a portfolio are seeded by
different paths at different moments and a FK would make the first read of a
never-invited-but-verified token fail instead of seed (OD-3).

### 4.1 Seeding by hand, for one owner or a roomful

Nobody *needs* this to see the demo: `PersistentPortfolioProvider.get` seeds
on a miss, so the first read of a new owner makes their portfolio. It exists
for the two things a first read cannot do — **warm** an account before its
owner has ever signed in, and **reset** one somebody has already moved
around during a rehearsal.

```
python -m app.jobs.seed_portfolios <email> [<email> ...] [--reset]
```

- **Several addresses, one invocation.** They are the positional arguments,
  and a comma inside one separates further addresses — chosen because
  `gcloud run jobs execute --args=a@x,b@y` hands the container exactly that,
  and a pasted list is what a human types. One run sets up a whole demo
  audience; it never needs *N* invocations.
- **Re-running is safe by construction.** An owner who already has a
  portfolio is **skipped** — not upserted, not appended, not doubled — so a
  list that overlaps a previous run costs nothing. `--reset` is the opposite
  instruction said out loud: replace what is there with a freshly seeded
  copy at today's `as_of`. That is the answer to *"idempotent upsert or
  wipe-and-recreate?"*: **idempotent by default, wipe-and-recreate only when
  asked**, because a demo that silently rewinds the portfolio somebody is
  standing in front of is worse than one that does nothing.
- **A bad address stops the run** before anything is written, rather than
  seeding a portfolio nobody will ever read.
- **The addresses are never logged** (§5). The job reports `seeded`,
  `skipped` and `total`, exactly as `provision_admins` does.

| Where | The exact command |
|---|---|
| Local stack | `docker compose exec backend python -m app.jobs.seed_portfolios lbertuzzi@somniosoftware.com demo@somnio.dev` |
| Local, no container | `cd backend && make seed OWNERS="lbertuzzi@somniosoftware.com demo@somnio.dev"` (add `RESET=1` to replace) |
| **dev**, after `backend-cd` has run | `gcloud run jobs execute finance-a2ui-dev-seed-portfolios --region us-central1 --project <project> --wait --args=lbertuzzi@somniosoftware.com,demo@somnio.dev` |
| dev, resetting | the same with `--args=--reset,lbertuzzi@somniosoftware.com` |

The Cloud Run job is `infra/run.tf::google_cloud_run_v2_job.seed_portfolios`,
shaped exactly like `purge_audit` (same image, same service account, same
secrets, no HTTP surface). Its default audience is
`var.seed_portfolio_owners`, which `infra/variables.tf` defaults to
`["lbertuzzi@somniosoftware.com"]`; `--args` overrides it per execution,
which is why the audience is an *argument list* and not an environment
variable.

**Nothing runs it for you.** `deploy_cloud_run.sh` executes the `migrate`
job and not this one, and no Cloud Scheduler points at it — deciding who
gets a portfolio is not a thing a deploy should do on its own, and a deploy
that quietly reseeded an account mid-rehearsal would be data loss with a
green checkmark. `infra/scripts/tests/test_dev_environment.sh` asserts both
halves: that the job exists, and that the deploy script never mentions it.

## 5. Security notes

**Authentication and authorization are unchanged.** Both options ride
`GET /v1/portfolios/{id}/views` and `POST /v1/view-renders`, which already
require a bearer token, sit behind the `views.read` feature gate and are
rate-limited per token. No new route, no new scope, no new audit action —
reading one's own portfolio is not an identity action and never was.

**The ownership key is the change with a threat model.** `owner_key` is
derived from the **verified** `email` claim of a token this service itself
validated (`auth/providers/*`), never from a header, a query parameter or a
body. A caller still cannot name another owner: `portfolio_id` accepts only
the well-known `current`, and `ViewService.portfolio` raises `NotFoundError`
for anything else (spec 0005 §5). Moving the key from `sub` to `email`
**widens** what one token can reach by exactly one step — two tokens for the
same verified e-mail now share one portfolio — and that is the intent
(OD-1). It also means an identity provider that let an address be claimed
without verification would be an account-takeover path; Firebase does not,
and the `jwt` preview sign-in only mints tokens for e-mails already
provisioned in `users` (0027 OD-3).

**Personal data.** `portfolios.owner_email` is the first place this service
stores an e-mail outside `users`. It is Confidential under the same
classification (`docs/compliance/DATA_CLASSIFICATION.md`), is never logged —
`portfolio.seeded` deliberately carries `as_of` and the symbol set and no
owner, and that comment stays — and is covered by the same deletion path as
the rest of the row. The `query` a caller types is **never logged either**:
it is a user-supplied string that could carry anything.

**Input handling.** `query` is bounded twice — `max_length=24` plus a
character pattern at the endpoint, `max_length=24` on the projection's own
options model — and is used only as a `str.casefold()` substring test. It
reaches no SQL (the ledger is filtered in memory, after the repository has
read it by owner), no template, no regex compiled from input and no log
line. `asset_class` is a closed `Literal`. Both are ADR-K D-3 declared
options: anything undeclared or out of range is a 422 rather than a
best-effort guess.

## 6. Rulings

- **OD-1 — the ownership key is the verified e-mail, lower-cased; the `sub`
  is the fallback, not the key.** `Principal.owner_key` returns
  `email.lower()` when the token carries one and `subject` otherwise. Both
  providers supply `email`: the `jwt` preview sign-in mints it (0027 OD-3)
  and Firebase always carries it for the two enabled methods. The fallback
  exists for a machine token with no `email` claim, which would otherwise
  have no portfolio at all. This is the same join key 0027 OD-1 chose, for
  the same reason, and it inherits the same cost: an e-mail changed at the
  identity provider is a new owner here.
- **OD-2 — a signed-in user who has not been seeded gets their own copy of
  the same curated portfolio, made on their first read.** Not an empty
  portfolio, not a 404, and not somebody else's row. Keyed by *their*
  e-mail and independently theirs from then on: a mutation saved for one is
  invisible to every other, which `uq_portfolios_owner_email` and the
  per-row `as_of` already guarantee. So there are two ways to have one —
  a human ran §4.1 for you, or you signed in — and **they produce the same
  portfolio**, because both call `seed_portfolio(as_of=...)`. The only
  difference is `as_of`, which is the moment it was made either way.
  - *Rejected — an empty portfolio for anyone but a named owner.* This is a
    **showcase**: its value is that any invited person — a Somnio engineer,
    someone at Google — opens it and sees the charts. An empty portfolio
    would need an empty state for all eleven projections and would turn
    every demo into a support question. The gate that decides who may see
    anything at all is the `users` registry (0027), and it already exists.
  - *Rejected — 404 for a non-owner.* A demo must never open on an error
    (spec 0003 OD-7).
  - So *"the seeded data belongs to `lbertuzzi@somniosoftware.com`"* is true
    in the sense that now holds water: when he signs in, the row is his, it
    says so in a column you can read, and it is not the same row anyone else
    is looking at. **No e-mail address is hard-coded anywhere for this** —
    an allow-list would have put a named person into an open-source
    repository and would have needed a second tier of behaviour to go with
    it.
- **OD-3 — no foreign key from `portfolios` to `users`.** Ownership is a
  value (an e-mail), not a reference. A verified token whose e-mail is not
  in the registry never reaches a projection — `GET /v1/me/access` and the
  client's gate stop it first — but making the *database* enforce that would
  couple seeding to provisioning order and turn a first read into a 500.
- **OD-4 — a search narrows the list; it does not restate the portfolio.**
  `holdings.positions.v1` keeps `total`, `gain` and each row's `weight` as
  facts about the **whole** portfolio while `positions` is filtered. A
  header that changed to "the total of what you searched for" would be a
  second, differently-scoped total on a screen that already shows the real
  one, and `weight` would stop meaning *share of the portfolio*. Rejected
  for that reason, and recorded because the opposite choice is the one a
  reader expects.
- **OD-5 — a term badge names the term and the sign.** `TERM_BADGES` printed
  `ST gain` / `LT gain` unconditionally, which was invisible while the seed
  held exactly one sale and that sale was a gain. This spec adds losses, so
  the badge becomes `ST gain` · `ST loss` · `LT gain` · `LT loss` (and
  `ST even` · `LT even` for an exactly-zero result, which the seed does not
  contain but the type permits). The colour still comes from `term`, as
  `Activity.dc.html` draws it — amber ST, teal LT; the word now comes from
  the sign.
- **OD-6 — the search matches domain fields, never rendered ones.** Matching
  `Transaction.symbol`/`memo` rather than the row's `title`/`detail` means a
  search result cannot change because a caption was reworded, and it means
  the same query returns the same rows in every `locale`. The cost is that
  typing `bought` matches nothing; the chips are what scope by kind, and
  that is what they are for.
- **OD-7 — the curated ledger stays hand-reconciled with the lots.** Every
  new sell is paid for by raising the matching buy's quantity by exactly the
  quantity sold, at the same unit price, so *buy − sells = the lot*, to the
  unit and to the cent. That is why the portfolio totals in §7 AC-7 are
  unchanged: **no lot is added, removed or altered by this spec.** One
  deliberate exception: a TSLA round trip that is bought and fully sold, so
  the ledger shows a closed position the holdings list correctly does not.
- **OD-11 — the agent cannot reach the income this spec seeds, and that is
  recorded rather than fixed here.** Asked *"what did I earn in dividends
  this year?"* against the local stack, the turn answers *"dividend income
  data is not available"* — correctly, because no tool exposes the ledger:
  `agent/tools/` reaches holdings, lots, attribution, payoff and the order
  draft, and nothing reads `Portfolio.transactions()`. This spec quadruples
  the dividend rows the Activity tab shows, which makes the gap *more*
  visible, so it is named here: a `dividend_income` tool (or a ledger tool
  the model can filter through the same `kind`/`query` vocabulary) is a
  separate spec, because it needs its own `*Display` figures, its own prompt
  fragment and its own period rule — *this year* is a calendar question the
  domain does not currently answer. Writing one inside a seed change would
  be the numbers-from-tools invariant decided in passing.
- **OD-8 — income and deposits still do not move the cash lot.** Twenty-five
  income rows now sit against a `USD` balance that is seed data. That was
  already recorded in 0028 and is now much more visible, so it is restated:
  the ledger is a *history the design draws*, not a double-entry system, and
  making it one would change every figure on Home and Holdings for no gain
  the showcase can use.

## 7. Acceptance criteria

1. **AC-1** — `portfolios` has `owner_email varchar(320) not null` with a
   unique constraint, and no `subject` column; `alembic upgrade head` then
   `downgrade -1` round-trips on an empty and on a populated database.
2. **AC-2** — Two principals with the same lower-cased e-mail and different
   `sub` read the **same** portfolio row; two with different e-mails read
   different rows; a principal with no `email` claim is keyed by its `sub`.
3. **AC-3** — The seeded ledger holds 48 rows: 16 `buy`, 7 `sell`, 16
   `dividend`, 9 `deposit`. Every chip therefore returns at least seven rows.
4. **AC-4** — For every sold symbol, the sum of that symbol's buys minus the
   sum of its sells equals the open lot's quantity, and the buys' cost minus
   the consumed cost equals the lot's `cost_basis`. (TSLA is the round trip:
   it nets to zero and holds no lot.)
5. **AC-5** — The seven sells realise three gains and three losses across
   both terms (TSLA is the seventh, a short-term gain), and each prints the
   badge its sign and term earn: `ST gain`, `ST loss`, `LT gain`, `LT loss`.
6. **AC-6** — `?view=activity.timeline.v1&query=payroll` returns only the
   payroll deposits; `&query=nvda` only the NVDA rows; `&kind=sell&query=voo`
   only the VOO sale; `&query=%20%20` (blank) returns everything.
7. **AC-7** — `?view=holdings.positions.v1&asset_class=bonds` returns the
   three bond rows; `&query=vanguard` returns VOO, BND and VNQ; **`total`,
   `gain` and every `weight` are byte-identical to the unfiltered render**.
8. **AC-8** — A filter that matches nothing returns `groups: []` /
   `positions: []` together with the projection's `empty` sentence, and
   never a 404 or a 422.
9. **AC-9** — `query` longer than 24 characters, or carrying a character
   outside the declared pattern, or an `asset_class` outside the enum, is
   **422** at the endpoint; `activity.timeline.v1` sending `asset_class`, or
   `holdings.positions.v1` sending `kind`, is 422 from the projection's own
   options model.
10. **AC-10** — `python -m app.jobs.seed_portfolios a@x.test b@y.test` seeds
    two owners; running it again seeds none and skips two; with `--reset` it
    seeds two again; a value with no `@` exits before writing anything.
11. **AC-11** — `GET /v1/views` advertises the new options, the OpenAPI
    document carries them with examples, and both catalog artefacts
    (`docs/catalog/CONTRACT.md`, `docs/catalog/view-catalog.snapshot.json`)
    are regenerated and committed. `make gate` green: 100 % branch coverage.

## 8. Test plan

| AC | Unit test(s) | Integration test(s) |
|---|---|---|
| AC-1 | — | `tests/integration/test_portfolio_repository.py` (existing suite, over `owner_email`) |
| AC-2 | `tests/unit/core/test_principal_owner_key.py`, `tests/unit/services/test_portfolio_service.py` | `tests/integration/test_portfolio_repository.py::test_two_subjects_one_email_share_a_portfolio` |
| AC-3, AC-4 | `tests/unit/domain/test_seed_ledger.py` — counts, and the buy/sell/lot reconciliation walked from the data itself | — |
| AC-5 | `tests/unit/presentation/test_activity_timeline.py` | — |
| AC-6, AC-8 | `tests/unit/presentation/test_activity_search.py` | `tests/integration/test_views_flow.py` |
| AC-7, AC-8 | `tests/unit/presentation/test_holdings_positions.py` | `tests/integration/test_views_flow.py` |
| AC-9 | `tests/unit/api/test_portfolio_views.py`, `tests/unit/schemas/test_view_options.py` | — |
| AC-10 | `tests/unit/jobs/test_seed_portfolios.py` | `tests/integration/test_seed_portfolios_job.py` |
| AC-11 | `tests/unit/presentation/test_catalog_contract.py` (re-render + diff, existing) | — |

Mutation checks required (auth / rate limit / error masking): **no new
surface** — the two options ride the existing authenticated, rate-limited,
feature-gated route. The reconciliation assertion of AC-4 is mutation
checked instead: changing one seeded quantity by one unit must make
`test_seed_ledger.py` red, and is shown to.

## 9. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-9 | Should a deployed environment ever *pre-seed* a named owner's portfolio before their first sign-in (so the very first screen is warm)? | TL | No — seed on first read, as today. A pre-seed job would need an e-mail list in Terraform. |
| OD-10 | Does design want a search affordance on Holdings at all, or only the class filter? Its page draws a magnifier on both tabs but no search state. | Design | Ship both; the option is declared and the client can drop the control without a backend change. |

## 10. Rollout & observability

No feature flag: the options are additive and default to today's behaviour,
so a client that sends neither sees exactly what it sees now. The migration
is ordered before the image that reads `owner_email` — the existing
`backend-cd` sequence (migrate job, then a no-traffic revision, then the
traffic shift) already provides that, and the column is `not null` with no
default, so an old image writing `subject` would fail loudly rather than
write a row nobody can read. **The portfolio table is emptied by the
migration**; the first read of each signed-in user reseeds it and logs
`portfolio.seeded` as it already does. To warm the demo audience instead of
waiting for their first sign-in, a human runs the §4.1 command **after** the
deploy — nothing does it automatically. One new log event,
`portfolios_seeded` (counts only, no addresses), emitted by that job. No new
metric.
