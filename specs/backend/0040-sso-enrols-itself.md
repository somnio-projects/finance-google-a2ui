# 0040 — SSO enrols itself, and the screen says so

- **Area:** backend (the provisioning decision), frontend (the window it opens)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this; none is invented here_
- **Also:** [`backend/0027`](0027-provisioning.md) (the registry), [`frontend/0020`](../frontend/0020-transition-states.md) OD-1 (spinner vs skeleton)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-23

## 1. Problem

The TL, signing in to the deployed app with two Google accounts:

> *"estoy logueando con esos usuarios y me tira: This account isn't
> provisioned for the preview… necesito que pueda loguear con SSO libremente,
> no vamos a tener restricciones aún… el aprovisionamiento debería hacerse de
> manera automática."*

Only `lbertuzzi@somniosoftware.com` was provisioned, from
`AUTH_BOOTSTRAP_ADMINS`. Everyone else got the registry's refusal, which is
exactly what spec 0027 designed — invite-only — and is no longer what this
deployment wants.

A second defect surfaced while looking: the window between *the provider
vouched* and *the registry answered* was **invisible**. `_admit` assigned a
state and never emitted it, so the sign-in form stayed on screen unchanged
and somebody who had just signed in saw the button they had pressed.

## 2. Rulings

- **OD-1 — the registry fills itself in; it is not bypassed.** An unknown
  verified identity is written as an `active` `member` and the turn is
  audited as `user.self_enrolled` with `invited_by = self-enrolment`. Letting
  SSO *skip* the registry would have left every later decision reading a
  table that does not describe who is using the app.

- **OD-2 — `revoked` and `requested` are never enrolled.** This is the ruling
  that matters. An offboarding somebody performed must not be undone by
  signing in again; a `requested` row is waiting on a decision that is still
  an admin's. Only the **absence** of a row enrols.

- **OD-3 — never an admin.** The first admins come from
  `AUTH_BOOTSTRAP_ADMINS` and nothing else creates one (0027 OD-2).

- **OD-4 — a switch, off by default.** `AUTH_OPEN_ENROLMENT`. The sign-in
  screen says *"Access is invite-only during the A2UI preview"*, and that is
  true of every deployment that does not opt in. A deployment that opts in is
  saying the opposite, deliberately. **The screen's sentence is now false on
  dev**, and it is chrome the client writes — see §5.

- **OD-5 — no background job, and the measurement is why.** The TL asked for
  one so provisioning could not block the API. Measured against the seeded
  stack with a brand-new identity: the first read — which also seeds sixteen
  lots and forty-eight transactions — answers in **105 ms**, the second in
  **7 ms**. A queue would replace a hundred milliseconds nobody notices with
  a wait somebody has to be told about, plus a runner, a status endpoint and
  a polling client. If enrolment ever grows real work, this is the ruling to
  revisit, and the number above is what to compare against.

- **OD-6 — the wait is a state, not a gap.** `AuthStatus.provisioning` is
  emitted before the access call. `SignInStatus.provisioning` keeps the
  buttons disabled — offering them again invites a second sign-in on top of
  the first — and draws one line with a spinner. It is the **third** entry in
  `actionSpinners`, and the count in that assertion was edited in the same
  commit, which is what it exists to force. It is not a skeleton because
  there is no page to skeleton: the form has no payload and is still on
  screen.

- **OD-7 — `config.py` and `user_service.py` both hit the 150-line budget.**
  `config.py` split along the seam `config_parsing.py` already drew — an
  `AuthSettings` mixin, fields only; the derived `admin_mfa_required` stays
  on `Settings` because it reads `is_production`, and an environment is not
  an authentication setting. Enrolment left `UserService` for
  `user_enrolment.py`: it is a use case, not a third way of reading the
  registry.

## 3. Acceptance criteria

1. **AC-1** — with the switch on, an unknown verified identity is admitted as an active member.
2. **AC-2** — it is written to the registry as `self-enrolment` and audited once.
3. **AC-3** — a second sign-in is a welcome back, not a second enrolment.
4. **AC-4** — a `revoked` or `requested` row is left exactly as it was, and still refused.
5. **AC-5** — a token with no e-mail claim enrols nothing.
6. **AC-6** — with the switch off, the behaviour is unchanged.
7. **AC-7** — the sign-in screen says an account is being set up, and its buttons stay disabled.
8. **AC-8** — both gates green.

## 4. Test plan

| AC | How |
|---|---|
| 1, 2, 3, 6 | `test_self_enrolment.py` — the same caller and the same empty registry under both switch positions |
| 4 | the same file, parametrised over `revoked` and `requested`, asserting the row is **unchanged** as well as refused |
| 5 | the same file |
| 7 | `sign_in_provisioning_test.dart`, and the four bloc sequences that now carry the state |
| 8 | `cd backend && make gate`, `cd frontend && make gate` |

## 5. Out of scope, and one thing that is now wrong

> **Closed on 2026-09-24 by [0043](0043-the-screen-can-ask-which-door-this-is.md)**,
> which took the first of the two options named below. Left as written,
> because what it says about *why* the screen could not know is still the
> reasoning, and because it took two specs recording the same gap before it
> was worth fixing — which is itself the record.

**The sign-in screen still reads *"Access is invite-only during the A2UI
preview."*** With `AUTH_OPEN_ENROLMENT=true` that sentence is false. It is
client chrome with no signal behind it, and giving it one is a contract
change — `/v1/me/access` is only called *after* sign-in, so the screen cannot
know before. Options are a public capability endpoint or a build-time flag;
neither is obviously right and both are bigger than this. **Named here rather
than left for a reader to notice**, because an open deployment telling people
it is invite-only is the kind of small untruth this repository keeps trying
not to ship.
