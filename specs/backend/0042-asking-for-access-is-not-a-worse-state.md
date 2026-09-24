# 0042 — Asking for access is not a worse state

- **Area:** backend (the enrolment predicate, and the provisioning job)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this; none is invented here_
- **Also:** [`backend/0040`](0040-sso-enrols-itself.md) (open enrolment — this **corrects** its OD-2), [`backend/0041`](0041-a-job-provisions-the-demo-audience.md) (the job — this corrects its OD-2 too), [`backend/0027`](0027-provisioning.md) (the registry)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-24

## 1. Problem

With open enrolment live and the provisioning job run over all five dev
accounts, a colleague still saw **"This account isn't provisioned for the
preview."**

Two rules, each defensible alone, combined into a trap:

- **0040 OD-2** — open enrolment admits a caller only when the registry has
  **no row**, so `revoked` cannot be undone by signing in again.
- **0041 OD-2** — the provisioning job never touches an existing row, for the
  same reason.

`POST /v1/access-requests` — the **"Request access"** link the sign-in screen
offers directly under the button somebody was just refused by — writes a row
with status `requested`. From that moment neither path will move them:
enrolment sees a row, the job sees a row. **Clicking the link the screen
recommends made the person permanently worse off than doing nothing.**

It is not hypothetical. The dev service logged two of them:

```console
$ gcloud logging read '…requestUrl=~"access-requests"' --freshness=72h
2026-09-23T20:28:19Z  POST  202  /v1/access-requests
2026-09-22T18:20:25Z  POST  202  /v1/access-requests
```

and the job's own report named them without naming them —
`added=2 untouched=3` over five addresses, where only one (the bootstrap
admin) should have been untouched.

## 2. Rulings

- **OD-1 — `requested` is admitted while enrolment is open.** 0040 OD-2
  reasoned that a request "waits on a decision that is still an admin's". With
  enrolment **open** there is no admin left to wait for: the deployment has
  already decided to admit everybody. The reasoning was sound for a closed
  preview and wrong the moment the switch was turned on.

- **OD-2 — `revoked` stays absent from the enrollable set, and that is the
  property the whole change must not cost.** An offboarding somebody
  performed is never undone by signing in again. It is now a named frozen set
  (`ENROLLABLE = {None, "requested"}`) rather than an `is None` check, so the
  distinction is a declaration rather than an implication.

- **OD-3 — the job promotes `requested` and nothing else.** An operator
  naming an address *is* the decision the request was waiting for.
  `active` and `invited` are already in; `revoked` is a decision. The job's
  counts keep their meaning: an already-active account is still `untouched`.

- **OD-4 — the closed-preview behaviour is unchanged, and a test says so.**
  With `AUTH_OPEN_ENROLMENT=false`, a `requested` row is still refused and
  still waits for an admin. The switch is what decides; this spec did not
  quietly open a deployment that had not opted in.

- **OD-5 — what this does not fix.** *(Fixed on 2026-09-24 by
  [0043](0043-the-screen-can-ask-which-door-this-is.md): the deployment now
  names its door and the screen shows this line only where it is true.)* The
  sign-in screen still offers *Request
  access* on an open deployment, where it now does nothing useful: the next
  sign-in would have admitted the person anyway. That link, and the
  *"invite-only"* sentence above it, are both client chrome with no signal
  behind them — the same gap 0040 §5 already records. Named again here
  because this is the second defect to come out of it.

## 3. Acceptance criteria

1. **AC-1** — with enrolment open, a `requested` row is admitted and becomes `active`.
2. **AC-2** — with enrolment closed, a `requested` row is still refused and left as it was.
3. **AC-3** — a `revoked` row is refused and left untouched in both cases.
4. **AC-4** — the job promotes `requested` to an active member.
5. **AC-5** — the job still leaves `active`, `invited` and `revoked` exactly as they were.
6. **AC-6** — `cd backend && make gate` green.
7. **AC-7** — the two stuck dev accounts can sign in.

## 4. Test plan

| AC | How |
|---|---|
| 1, 2 | `test_self_enrolment_refusals.py` — the same `requested` row under both switch positions |
| 3 | the same file; asserts the row's status **and** `invited_by` survive |
| 4, 5 | `test_provision_users.py`; AC-5 is parametrised over the three untouched statuses |
| 6 | the gate |
| 7 | a real sign-in, after the deploy |

## 5. Out of scope

Everything in OD-5, and removing the *Request access* affordance. It is right
for a closed preview and this repository will want one again.
