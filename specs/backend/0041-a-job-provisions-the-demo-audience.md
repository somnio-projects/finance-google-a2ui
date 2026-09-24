# 0041 — A job provisions the demo audience

- **Area:** backend (a Cloud Run job), infra (the job and its IAM)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this; none is invented here_
- **Also:** [`backend/0040`](0040-sso-enrols-itself.md) (open enrolment), [`backend/0027`](0027-provisioning.md) (the registry), [`backend/0035`](0035-the-portfolio-has-an-owner-and-the-tabs-really-filter.md) §4.1 (the seed job this copies)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-24

## 1. Problem

Five accounts exist in Firebase Auth on dev; **one** was in the provisioning
registry. The TL: *"necesito que se aprovisionen porque si no van a quedar
muertas… y necesito habilitarlas para la demo."*

They will not stay dead — spec 0040 shipped open enrolment, so each of them
gets a row on their first sign-in. What is genuinely missing is the row
**beforehand**, and there was no way to write one:

- the admin API (`POST /v1/admin/users`) needs an admin token, and dev sets
  `AUTH_ADMIN_REQUIRE_MFA=true`, so the `admin` scope requires an `amr` a
  minted token does not carry;
- Cloud SQL is on a private VPC, so no client reaches it from a laptop;
- `AUTH_BOOTSTRAP_ADMINS` would work and makes every address an **admin**,
  which is the wrong grant for a demo audience.

So the answer is a job, shaped exactly like `seed_portfolios` — which the TL
already uses and asked to keep open for arbitrary addresses.

## 2. Rulings

- **OD-1 — members, never admins.** The first admins come from
  `AUTH_BOOTSTRAP_ADMINS` and nothing else creates one (0027 OD-2). This job
  writes the audience; it does not create operators.

- **OD-2 — an existing row is never touched, whatever its status, and there
  is no `--reset`.** `revoked` is an offboarding somebody performed; a flag
  that overwrote it would be a way back in that no audit reader would expect
  from a provisioning run. The seed job *has* `--reset` because replacing a
  portfolio is reversible and harms nobody; replacing an account's status is
  neither. **The two jobs differ here on purpose.**

- **OD-3 — one normalisation, two jobs.** `owners_from` is imported from
  `seed_arguments` rather than copied: both jobs take the same kind of list —
  comma-separable, lower-cased, de-duplicated, rejected loudly on a typo —
  and a second copy is a second place for those rules to drift.

- **OD-4 — the address list is empty by default and an argument-less run
  fails.** Same reason `seed_portfolio_owners` is (0035 OD-2): an address in
  an open-source repository is somebody's name, and nobody should be
  provisioned because a default said so. It is overridden per run with
  `gcloud run jobs execute --args=a@x,b@y`.

- **OD-5 — addresses are never logged.** The job reports counts
  (`added`, `untouched`, `total`), exactly as `provision_admins` and
  `seed_portfolios` do. E-mails are PII (`security.md`) and a Cloud Run job's
  exception is a log line.

## 3. Acceptance criteria

1. **AC-1** — an unknown address becomes an `active` `member` recorded as `provision-users-job`.
2. **AC-2** — an existing row is returned untouched in every status, including `revoked`.
3. **AC-3** — re-running the same list adds nothing the second time.
4. **AC-4** — a mixed list reports both counts.
5. **AC-5** — `--reset` is rejected by the parser.
6. **AC-6** — the job exists in Terraform with the delivery label, `ignore_changes` on its image, and a deployer IAM binding.
7. **AC-7** — `cd backend && make gate` green; the infra suites green.
8. **AC-8** — the four unprovisioned dev accounts have rows after one run.

## 4. Test plan

| AC | How |
|---|---|
| 1–5 | `test_provision_users.py`, over the same fake repository the service suite uses; AC-2 is parametrised over all four statuses and asserts role, status, `invited_by` **and** display name all survive |
| 6 | `test_dev_environment.sh` — its per-job loop already requires the label, `ignore_changes` and the binding for **every** job found in `run.tf`, so the new one was red until all three existed |
| 7 | the gates |
| 8 | the run itself, output in the PR |

## 5. Out of scope

Removing somebody. `PATCH /v1/admin/users/{email}` already does that and is
an admin's decision, not a job's — which is the same reasoning as OD-2 read
from the other side.
