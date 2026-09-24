# 0027 — User provisioning: sign-in is invite-only

- **Area:** backend + frontend
- **Status:** In progress
- **Ticket:** _unassigned — GGU-115 is a local number; create the Jira ticket before the release PR_
- **Also:** 0001 (foundation, `/v1/me`), 0002 (feature flags, the `admin` scope), 0004 (audit trail), [ADR-B](../../docs/adr/ADR-B-auth-credential-contract.md) (amended here, D-13)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

`Login.dc.html` says, in its own words: *"Firebase Auth with gated,
invite-only provisioning. Sign-in-first: no open self-signup."* Its third
state is an error snackbar — *This account isn't provisioned for the
preview.* — and its footer has a *Request access* link. None of that existed:
every route accepted any verified token (ADR-B D-5 as amended: "accounts are
provisioned by us, never self-signup" — at the identity provider, by hand),
the client carried a development token compiled into the bundle
(`frontend/SECURITY.md` G-1), and when that token expired the person saw the
tab bar and an error instead of a sign-in screen.

The identity provider answers *who*. Nothing answered *whether*.

## 2. Decision

**Provisioning moves into this service, as data.** A `users` table is the
registry of who was invited; an identity provider (Firebase in every deployed
environment, the HS256 `jwt` provider on a laptop) still proves identity, and
`GET /v1/me/access` joins the two: *this verified e-mail — is it invited?*
The answer is a DTO with the sentence the client shows verbatim, never a
guess made on the device (N-9).

Administration is an API, not a console: `admin`-scoped routes invite,
approve, revoke and list, each audited under `user.*` with the e-mail as
`target`. The first admins come from configuration at boot (OD-2), because a
registry with no admin can never gain one through the API.

## 3. API contract

| Method & path | Auth | Request | Response | Errors (code → status) |
|---|---|---|---|---|
| `GET /v1/me/access` | Bearer | — | `200` `AccessResponse{email, provisioned, status, role, display_name, message}`; an `invited` account becomes `active` (audited `user.activated`) | `auth/* → 401`, `429`, `503` |
| `POST /v1/access-requests` | **none** | `AccessRequest{email}` | `202`, no body, whether or not the e-mail is known | `validation-failed → 422`, `429`, `503` |
| `POST /v1/preview-sign-ins` | **none** | `PreviewSignIn{email}` | `201` `PreviewSignInResponse{access_token, token_type, expires_in}`; audited `user.preview_sign_in` | `not-provisioned → 403`, `feature-disabled → 404` (any stack not `jwt` + enabled), `422`, `429`, `503` |
| `GET /v1/admin/users` | Bearer + `admin` | `?limit=1..200` | `200` `[UserResponse]`, newest first; audited `user.list` | `forbidden → 403`, `401`, `422`, `429`, `503` |
| `POST /v1/admin/users` | Bearer + `admin` | `UserInvite{email, display_name?, role}` | `201` `UserResponse` + `Location`; creates as `invited` or moves `requested`/`revoked` back to it; audited `user.invited` | `403`, `401`, `422`, `429`, `503` |
| `PATCH /v1/admin/users/{email}` | Bearer + `admin` | `UserStatusUpdate{status}` | `200` `UserResponse`; audited `user.<status>` | `not-found → 404`, `403`, `401`, `422`, `429`, `503` |

Statuses: `requested` (asked, waiting) · `invited` (may sign in; becomes
`active` on first access) · `active` · `revoked` (offboarded; the row stays
as the record). `PROVISIONED = {invited, active}` is the one predicate every
decision reads. Roles: `member` · `admin`; a token's `roles` claim is what
the verifier already turns into scopes, so an `admin` row minted through the
preview sign-in holds the `admin` scope.

## 4. Data model & migration

Alembic revision **`0006`** (`20260921_0006_users.py`, revises `0005`):

```
users(
  id            uuid          primary key,
  email         varchar(320)  not null unique,     -- lower-cased; the join key to a token's `email`
  display_name  varchar(120)  null,
  role          varchar(16)   not null check (role in ('member','admin')),
  status        varchar(16)   not null check (status in ('requested','invited','active','revoked')),
  invited_by    varchar(320)  null,                -- an admin's e-mail, or `bootstrap`
  last_seen_at  timestamptz   null,
  created_at    timestamptz   not null default now(),
  updated_at    timestamptz   not null default now()
)
```

No credential is stored, ever: the table has no password, no token and no
provider id — the identity provider keeps those.

## 5. Rulings

- **OD-1 — the join key is the e-mail, not the `sub`.** An inviter knows an
  e-mail before the invitee has ever signed in, and both providers carry the
  claim. The cost is that an e-mail changed at the IdP is a new person here;
  accepted for a preview.
- **OD-2 — the first admins are configuration.** `AUTH_BOOTSTRAP_ADMINS`
  (comma-separated) are made active admins at startup, idempotently; a
  database that is not up yet is a warning, not a failed boot. The local
  stack's `docker-compose.yml` defaults it to `demo@somnio.dev`; Terraform
  sets nothing, so a deployed stack has exactly the admins it was told.
- **OD-3 — the local stack has no Firebase, so the design's *Continue with
  email* is answered by a preview sign-in.** `POST /v1/preview-sign-ins`
  mints the same HS256 token `make token` mints — for **provisioned** e-mails
  only, and only while `AUTH_PROVIDER=jwt` **and**
  `AUTH_PREVIEW_SIGN_IN_ENABLED=true`. Every deployed environment runs `oidc`
  and answers `404 feature-disabled`, exactly as if the route did not exist.
  This is an unauthenticated route by contract (like the health probes,
  ADR-B D-3), rate-limited per client, and it is the one place the service
  ever issues a credential; `docs/SECURITY.md` carries the row.
- **OD-4 — `GET /v1/me/access` always answers 200 for a valid token.** The
  decision is data the shell binds (`provisioned: false` plus the design's
  sentence), not an error — an error would make "not invited" look like
  "broken" in every client log.
- **OD-5 — `POST /v1/access-requests` never says whether an e-mail is known.**
  202 either way; an existing `active` account is not downgraded by asking.
- **OD-6 — Google SSO is the identity provider's, not ours.** The client
  signs in with Firebase (Google or e-mail) and presents the ID token; this
  service verifies it through the existing `oidc` provider and consults the
  registry. Enabling Google at the IdP amends ADR-B D-5a (below).

## 6. ADR-B amendment — D-13 (proposed)

**D-13 — Provisioning is a registry in this service, joined on the verified
e-mail.** Supersedes the "at the IdP, by hand" half of D-5: an account that
is not `invited` or `active` in `users` is told so by `GET /v1/me/access`,
whatever the identity provider said. D-5a stays a ruling; the design's
*Continue with Google* is the amendment that enables a second provider, to be
ratified by the TL with the Firebase project.

## 7. Test decision

Unit: `UserService` and `PreviewSignInService` against in-memory doubles
(every status, the MFA gate, the audit action per operation); the controllers
against a faked service (statuses, `Location`, 422s, the 404-when-disabled);
`build_token`'s claims. Integration: `UserRepository` against PostgreSQL,
including the error translation, and `provision_admins` landing rows
idempotently. `make gate` green: 100 % branch coverage.
