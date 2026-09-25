# 0045 — Every account gets today's seed

- **Area:** backend (`app/jobs/`, `app/repositories/user_repository.py`)
- **Status:** In progress
- **Supersedes nothing.** Extends `backend/0035` §4.1 (the seed job) after
  `backend/0044` (the portfolio is crypto).

## 1. The problem

`backend/0044` replaced the demo portfolio's contents: eight crypto assets in
place of seventeen equities. Every projection, every golden and every prompt
fragment moved with it, and the gate proved they did.

**What did not move is the data already in the environment.** A portfolio is
persisted per owner (`0020`, re-keyed by `0035`), and both paths that create
one refuse to touch an owner who already has one:

- `PersistentPortfolioProvider` seeds **on a miss**, so an existing row is
  never revisited;
- `seed_portfolios` **skips** an owner who has a portfolio, which is the
  property that makes re-running it safe.

So an account seeded before 0044 still holds equities, on a build whose code,
catalog and client are entirely crypto. `/health` reports the right commit, the
gate is green, and the screen shows AAPL. This was observed locally on
2026-09-25: the stack came up on the crypto commit and `portfolio_lots` still
held `AAPL, MSFT, NVDA, VOO, XOM` until the volume was wiped.

`--reset` already exists and is exactly the right instruction — but it must be
told **who**, one address at a time. Retyping the audience is how the set goes
wrong quietly: the run reports counts, never addresses (`0035` §5), so an
operator who forgot somebody gets a success message and a mixed environment.

## 2. Scope

One flag, one query, and the seam to hold them.

- `--all` on `seed_portfolios`: the owners come from the database instead of
  the command line.
- `UserRepository.list_admitted_emails()`: the population.
- `app/jobs/seed_population.py`: `selected_owners(...)`, the resolution.

Out of scope: any change to what the seed *contains* (0044 owns that), to the
lazy provider, or to `provision_users`.

## 3. Decisions

- **OD-1 — the population is the *admitted* accounts: `active` and `invited`.**
  `revoked` is excluded for the reason `provision_users` already states out
  loud — an offboarding somebody performed is not undone by a job run.
  `requested` is excluded for a subtler one: that account cannot sign in yet,
  so seeding it now fixes an `as_of` at today and the lazy provider will never
  replace it, handing the person a portfolio dated before they were admitted.
  The integration test asserts the filter against **all four** statuses rather
  than the two we expect, so a fifth status cannot quietly join the population.

- **OD-2 — a list and `--all` are mutually exclusive, and neither is a
  default.** Both "both" and "neither" are refusals. A precedence rule would
  make the difference between touching one account and touching every one of
  them depend on which argument the parser happened to prefer.

- **OD-3 — `--all` and `--reset` stay two words.** `--all` alone still skips
  owners who have a portfolio, which is the warming case: give the accounts
  that have none today's seed and leave everybody else alone. `--all --reset`
  is the destructive one — it replaces every admitted owner's portfolio — and
  saying it takes both words on purpose.

- **OD-4 — the population is read in the *same session* as the writes.**
  Resolving it on one connection and writing on another would let the set go
  stale between them, which on this job means an account registered mid-run is
  silently skipped by a command whose whole claim is *every*.

- **OD-5 — `list_admitted_emails` is deliberately unbounded**, unlike its
  neighbour `list_all(limit=...)`. A limit here would seed a subset and report
  success — the failure mode `ci-conventions.md` §5 keeps finding, in a job
  whose name is `--all`. The population is a demo audience, counted in tens; if
  it ever is not, the fix is pagination that still covers everyone, never a cap.

- **OD-6 — the module splits three ways, along the seam `0035` already cut.**
  `seed_arguments` decides who was *asked for*, `seed_population` resolves who
  *exists*, `seed_portfolios` writes. That is also what lets the resolution be
  tested against a fake repository instead of a patched session — the first
  draft of these tests monkeypatched `session_scope`, ran to 206 lines and
  asserted plumbing.

## 4. Acceptance criteria

1. **AC-1** — `python -m app.jobs.seed_portfolios --all --reset` replaces the
   portfolio of every admitted account with one seeded at today's `as_of`.
2. **AC-2** — `--all` without `--reset` seeds only the admitted accounts that
   have no portfolio and reports the rest as skipped.
3. **AC-3** — `revoked` and `requested` accounts are never written to.
4. **AC-4** — Naming addresses *and* `--all`, or neither, exits non-zero with
   a message; neither is silently resolved.
5. **AC-5** — The run reports counts only; no address reaches a log line
   (`0035` §5, `security.md`).
6. **AC-6** — `cd backend && make gate` green, 100 % branch coverage.

## 5. Test plan

| # | What | Where |
|---|---|---|
| 1 | Both refusals — a list with `--all`, and neither | `tests/unit/jobs/test_seed_population.py` |
| 2 | `--all` reads the population and ignores the argument list | same |
| 3 | A named list never queries the registry | same |
| 4 | The filter against **all four** statuses | `tests/integration/test_seed_population.py` |
| 5 | `--all` with a named list is refused before any write | (1) covers it at the parser) |
| 6 | `make gate` | — |

## 6. Operating it

Against a deployed environment, the job is a Cloud Run job execution:

```
gcloud run jobs execute seed-portfolios --region <region> --args=--all,--reset
```

The comma form is why `seed_arguments` accepts one, and it is what
`gcloud run jobs execute --args=` hands the container.

**This spec ships the capability, not the run.** `gcloud` is not installed on
the machine this was written on, so the execution against dev is a human step;
the PR body says so under *Not run* rather than implying the environment has
already been re-seeded.

## 7. Open decisions

| # | Question | Owner | Default if nobody answers |
|---|---|---|---|
| OQ-1 | Should `backend-cd` run `--all --reset` automatically after a deploy that changes the seed? | TL | No. A destructive data job on every deploy is a bigger decision than this spec, and the seed changing is rare |
| OQ-2 | Is there a status between `invited` and `active` we will want later (e.g. `suspended`)? | product | `ADMITTED` is a named tuple; adding one is one word and one test row |
