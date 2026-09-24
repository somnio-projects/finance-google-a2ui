# 0043 — The screen can ask which door this is

- **Area:** backend (a public capability read) and frontend (the sign-in screen that consumes it)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this; none is invented here_
- **Also:** [backend/0040](0040-sso-enrols-itself.md) §5 (which named this gap first), [backend/0042](0042-asking-for-access-is-not-a-worse-state.md) OD-5 (which named it again), [backend/0027](0027-user-provisioning.md) (the registry and the two public routes), [frontend/0008](../frontend/0008-sign-in.md) (the screen), [`.claude/rules/backend/security.md`](../../.claude/rules/backend/security.md) (adding a public route)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-24

## 1. Problem

`https://finance-a2ui.web.app` tells every visitor:

> Access is invite-only during the A2UI preview.  **Request access**

The dev deployment runs `AUTH_OPEN_ENROLMENT=true`. Anyone Google vouches for
is admitted on their first call (spec 0040). **Both halves of that line are
false**: access is not invite-only, and the link asks for something that would
have been granted anyway.

This was not missed. Spec 0040 §5 recorded it the day the switch shipped, and
spec 0042 OD-5 recorded it again nine days later as *"the second defect to come
out of it"*. Neither fixed it, for a stated reason worth repeating because it
is still true:

> …giving it one is a contract change — `/v1/me/access` is only called *after*
> sign-in, so the screen cannot know before.

The screen makes a claim about the **door**, and everything the client can
currently read is behind that door. There is no signal, so the sentence is a
build-time guess that happens to be wrong.

**Why this is worth a change rather than a deletion.** The sentence is not
merely decoration: on a closed deployment it is true, and *Request access* is
the only route to `POST /v1/access-requests` — the only way a stranger can ask
to be let in. Deleting the line would make the open deployment honest by
removing the closed one's only affordance. The deployment has two shapes, so
the screen needs to know which one it is in.

## 2. Rulings

- **OD-1 — the backend declares the door; the client does not infer it.**
  0040 §5 named two options: a public capability endpoint, or a build-time
  flag. The flag is refused. `AUTH_OPEN_ENROLMENT` already exists, on the
  service, as the single thing that decides; a `--dart-define` beside it would
  be a second declaration of one fact, free to disagree with the first, in a
  bundle compiled before the service was configured. That is the drift this
  repository has now written five separate checks against
  (`.claude/rules/ci-conventions.md` §5). **A deployment's behaviour is
  reported by the deployment.**

- **OD-2 — `GET /v1/sign-in-policy`, public by contract.** The third public
  route, joining `/v1/access-requests` and `/v1/preview-sign-ins` under the
  same reasoning (ADR-B D-3): *a person who cannot sign in yet has no bearer
  token to present*, and this is the one question they must be able to ask
  before signing in.

  `security.md` requires a public route to be justified in its spec, so:
  it takes no input, reads no table, opens no session, and answers one
  enumerated value. It carries **no subject data** — it cannot be asked about
  an e-mail, and its answer is identical for every caller. What it discloses
  is whether this deployment admits a verified identity, which any person with
  a Google account already discovers by pressing the button once. It is the
  same class of disclosure as the agent card: *what this service is*, not
  *who is in it*.

- **OD-3 — an enumerated value, not a boolean.** The field is
  `enrolment: "open" | "invite-only"`, not `open_enrolment: true`. A third
  door is plausible (domain-restricted enrolment was discussed for the demo
  and not built), and a `Literal` leaves room for it without a breaking
  change, while a boolean would have to become one.

- **OD-4 — the open door says nothing, and that is deliberate.** When
  `enrolment` is `open`, the screen shows **no** line where the invite line
  was. It does not say *"anyone can sign in"*.

  A true replacement sentence is tempting and was written and discarded: the
  copy on this screen is design's, from `Login.dc.html`, and design has never
  written a line for a door that did not exist when the page was drawn. A
  sentence invented here would be indistinguishable from one a designer
  approved — the same ruling
  [`presentation.md`](../../.claude/rules/backend/presentation.md) already
  makes about catalog guidance, applied to chrome. The Google button directly
  above it is the instruction.

  Naming it here so the next person does not read the empty space as an
  oversight: **the open deployment is silent on purpose, and a sentence for it
  is design's to write.**

- **OD-5 — unknown is silent, not invite-only.** Before the answer arrives,
  and if it never arrives, the screen shows nothing. Defaulting to the
  invite-only line would make a failed request print the exact untruth this
  spec exists to remove, and would do it precisely when the backend is
  unreachable — the moment the claim is least verifiable. The cost is named:
  **on a closed deployment whose policy read fails, the person loses the
  *Request access* link** and sees only the sign-in buttons. That is a
  degraded screen; the alternative is a confident false one.

- **OD-6 — the client asks once, on the sign-in screen, and nowhere else.**
  Not at bootstrap: `bootstrap.dart` is synchronous and constructs, it does
  not fetch. Not per rebuild. The bloc asks when it is created, which is when
  the page is, and holds the answer in its state like every other thing that
  screen knows.

## 3. API contract

```
GET /v1/sign-in-policy          → 200 application/json
```

```json
{ "enrolment": "open" }
```

| Field | Type | Meaning |
|---|---|---|
| `enrolment` | `"open"` \| `"invite-only"` | `open` — a verified identity the registry has never seen is admitted and enrolled (spec 0040). `invite-only` — only an `invited` or `active` account may in; everyone else is refused and may ask. |

No parameters, no body, no auth. Errors: `429` (the shared rate limit),
`500`, `503` — the standard problem+json set, from `problem_responses`.

## 4. Data model

None. No migration, no table, no column. The answer is
`Settings.auth_open_enrolment`, which spec 0040 added.

## 5. Security notes

- Public by contract (OD-2), added to `PUBLIC` in
  `tests/unit/api/test_openapi_contract.py`, which is the visible diff that
  makes a new public route a reviewed decision rather than a route that
  quietly stops declaring a 401.
- No audit event. Nothing identifies a caller, so there is no identity action
  to record; writing one per anonymous page load would be noise in the trail
  that `security.md` asks to keep readable.
- Nothing logged beyond the ordinary request line. No e-mail is involved.

## 6. Acceptance criteria

1. **AC-1** — with `AUTH_OPEN_ENROLMENT=true`, `GET /v1/sign-in-policy` answers `200 {"enrolment": "open"}`.
2. **AC-2** — with it false, the same route answers `200 {"enrolment": "invite-only"}`.
3. **AC-3** — the route needs no token: it answers the same with no `Authorization` header as with one.
4. **AC-4** — it is documented like every other operation (summary, description, `operation_id`, tags, `response_model`, responses, example) and the OpenAPI contract suite passes with it in `PUBLIC`.
5. **AC-5** — on an `invite-only` policy the screen shows the design's sentence and the *Request access* link, exactly as today.
6. **AC-6** — on an `open` policy it shows neither.
7. **AC-7** — before the answer arrives, and when the read fails, it shows neither (OD-5).
8. **AC-8** — the *Request access* sheet still works when the link is shown; nothing about the closed path changed.
9. **AC-9** — `cd backend && make gate` and `cd frontend && make gate` green.

## 7. Test plan

| AC | How |
|---|---|
| 1, 2 | `tests/unit/api/test_sign_in_policy.py`, parametrised over the switch |
| 3 | the same file — the route called with no header |
| 4 | `test_openapi_contract.py`, already parametrised over every operation |
| 5, 6, 7 | `app/test/features/sign_in/sign_in_policy_test.dart` — the line present, absent, and absent-while-unknown |
| 5, 6, 7 | `sign_in_bloc_policy_test.dart` — the three bloc sequences (open, invite-only, failure) |
| 8 | the existing `request_access_sheet` tests, unchanged |
| 9 | the two gates |

## 8. Out of scope

- **A sentence for the open door.** OD-4: design's to write. When it is
  written, it goes in `sign_in_footer.dart` beside the other one and this spec
  gets a pointer.
- **Caching the answer across screens.** It is read once per sign-in page and
  that is already once per session in practice. A cache would be a second
  place for it to be stale.
- **Whether `/v1/me/access` should also carry the policy.** It could, and it
  would be free — but it is read after sign-in, which is after the only
  moment this screen needs it. Recorded so it is not rediscovered as an
  optimisation.
