# ADR-B — Auth credential contract

- **Status:** Accepted (TL, 2026-09-18) · **amended 2026-09-20 — D-4 superseded by D-11/D-12; D-6's `auth/revoked-token` struck. The amendment is Proposed and awaits TL ratification**
- **Gates:** GGU-2 (client), GGU-46 (backend), GGU-87
- **Evidence anchor:** `main` @ `410bb9d`, `genui_a2a` 0.10.1 · amendment verified against `develop` @ `c1f758d`

## Context

> **In the context of** a public repository whose backend holds the team's Gemini key, with
> provisioned-only accounts and no user store of our own, **facing** the need for two developers to
> build the client and server halves in parallel against one credential contract, **we decided** to
> use the short-lived Firebase ID token as the sole backend credential, verified per request by the
> Firebase Admin SDK, **and neglected** (i) our own JWT/session cookie, (ii) a shared static API key
> and (iii) Cloud IAP on the Cloud Run service, **to achieve** a minimal standards-based control
> reusing the already-enabled emailPassword provider, **accepting that** every call pays a token
> verification, that tokens expire mid-stream, and that `genui_a2a 0.10.1` gives us no interceptor
> so refresh must mutate a per-connector header map.

> **"verified per request by the Firebase Admin SDK" is historical.** It records what was intended
> on 2026-09-18. What shipped is a provider-agnostic JWKS verifier and `firebase-admin` is not a
> dependency; the WH(Y) statement is left as written because it is the record of the decision as
> made, and D-11/D-12 carry what is true now. This sentence is the single reason D-4 asked for
> `check_revoked` — see the amendment.

### Two hard blockers discovered during refinement

1. **There is no seam to attach the header.** `LandingRepository` calls `A2uiAgentConnector(url: …)`, and that constructor path hardcodes `authHeaders: {'X-A2A-Extensions': …}` with no parameter to add more. GGU-2 must switch to the `A2uiAgentConnector(client: A2AClient(…))` form **and re-supply `X-A2A-Extensions` itself** — omit it and A2UI silently degrades to the text agent.
2. **There is no interceptor.** `HttpTransport.authHeaders` is `final Map<String, String>` but is spread **per request**. The only viable seam is a *mutable* map whose `Authorization` entry is rewritten before each send.

## Decision

- **D-1** Credential = Firebase **ID token** only. The refresh token MUST NEVER be sent to our backend; a test asserts the outbound request carries none.
- **D-2** Transport = `Authorization: Bearer <idToken>` on every A2A request, with `X-A2A-Extensions` preserved alongside it.
- **D-3** `GET /.well-known/agent-card.json` and `GET /health` are **unauthenticated**. Every other path requires a valid token.
- **D-4** ~~Verification asserts `iss == https://securetoken.google.com/finance-a2ui`, `aud == finance-a2ui`, unexpired, `check_revoked=True`.~~ — **superseded 2026-09-20 by D-11 and D-12.** The issuer, audience and expiry assertions are real and move to D-11 unchanged in substance. `check_revoked=True` was never built and cannot be built as written: it is a **Firebase Admin SDK** parameter (`firebase_admin.auth.verify_id_token`) and that SDK is not a dependency of this service. See the amendment below.
- **D-5** ~~Allow-list required~~ — **amended 2026-09-18 (TL): no uid allow-list.** Access control is (a) email/password is the sole enabled provider and (b) accounts are provisioned by us, never self-signup.
- **D-5a** **Email/password is the only enabled Firebase Auth provider.** Recorded as a ruling so that enabling a second provider is a deliberate amendment to this ADR rather than a silent console toggle — that toggle is the only way the D-5 control could quietly disappear.
- **D-6** Rejections use typed, distinguishable codes: `auth/missing-token`, `auth/invalid-token`, `auth/expired-token`, ~~`auth/revoked-token`~~ → `401`; `session-forbidden` → `403` (emitted as `forbidden`). **Amended 2026-09-20:** `auth/revoked-token` is struck — no such class exists in `core/errors.py` and, per D-12, nothing can raise it. The three surviving codes are implemented (`MissingTokenError`, `AuthenticationError`, `ExpiredTokenError`). A client MUST NOT branch on a code the backend cannot emit. See `docs/specs/GGU-3/api-contract.md` §6 (Draft, anchored at `410bb9d`) and the current wire format in `backend/src/app/schemas/problem.py`.
- **D-7** Client refresh policy: force-refresh + **exactly one** retry on `auth/expired-token`; any other 401/403 signs the user out. No retry loop.
- **D-8** The token is validated **once at stream open**. A token expiring mid-stream does not terminate the stream. *(Open: revisit against the Cloud Run request timeout.)*
- **D-9** Refresh seam: the connector holds a **mutable** `Map<String, String>` whose `Authorization` entry is rewritten before each send. Documented workaround pinned to `genui_a2a 0.10.1`; revisit on upgrade.
- **D-10** No credential, service account, `google-services.json` or `GoogleService-Info.plist` is committed. Only Firebase **public** config ships client-side.
- **D-11** **Verification asserts exactly six things, and nothing else:** the signature, `iss`, `aud`, `exp`, `iat` and a non-empty `sub`. Both providers do this and no more — `jwt_provider.py` (HS256, shared secret) and `oidc_provider.py` (RS256/ES256 against the provider's JWKS), each a single `jwt.decode(...)` with `options={"require": ["exp", "iat", "sub"]}`. Issuer and audience are **configuration** (`AUTH_ISSUER`, `AUTH_AUDIENCE`), not the literals D-4 hard-coded; the Firebase values are one deployment of a pluggable contract, which is what makes `AUTH_PROVIDER=jwt` possible in dev. `exp` is honoured with `AUTH_LEEWAY_SECONDS` of slack (default 30 s, bounded 0–300).
- **D-12** **There is no server-side revocation check, and revocation latency equals the token's remaining lifetime.** Revocation happens at the IdP; this service learns of it only by the token expiring. Concretely: **≤ 1 h + 30 s** for user ID tokens (Firebase ID tokens live one hour — a provider constant we do not configure — plus `AUTH_LEEWAY_SECONDS`), **≤ 10 min + 30 s** for minted service tokens ([`ACCESS_CONTROL.md`](../compliance/ACCESS_CONTROL.md) §3). For HS256 service tokens, rotating `AUTH_JWT_SECRET` invalidates every one of them at once; that is the only immediate break-glass this service has, and it does not exist for OIDC. **No `auth/revoked-token` code is emitted, and no code is emitted at all during that window** — a revoked-but-unexpired token still carries a valid signature and valid `iss`/`aud`/`exp`, so it is **accepted**. This is a residual risk that is accepted, not a gap that another layer closes.

## Consequences

D-5 accepts a real residual risk, bounded by D-5a: token verification alone admits any user in the
`finance-a2ui` project. With one provider and provisioned-only accounts that set equals the intended
set. Adding a provider without amending this ADR silently widens backend access to the Gemini key.

D-12 accepts a second one, and the two compose: the set of principals is "anyone in the project"
(D-5) and removing someone from that set takes effect at their next token expiry, not at the moment
of removal. Offboarding a person is therefore **disable at the IdP, then wait out the hour** — which
is what [`ONBOARDING_OFFBOARDING.md`](../compliance/ONBOARDING_OFFBOARDING.md) and
[`INCIDENT_RESPONSE_PLAN.md`](../compliance/INCIDENT_RESPONSE_PLAN.md) already say to do, and they
are right. What was wrong was this record claiming the wait did not exist.

## Amendment 2026-09-20 — a revocation check that was never built (GGU-87)

**Status:** Proposed. D-11 and D-12 are drafted against the code as it stands; ratifying them is
the TL's. **Documentation only** — no code changed, and none is asked for.

**What D-4 claimed.** Four assertions, of which three were built and one never was.
`check_revoked=True` is a keyword argument of `firebase_admin.auth.verify_id_token`. This service
does not use the Firebase Admin SDK: `firebase-admin` appears in neither `backend/pyproject.toml`
nor `backend/uv.lock`. The ruling named an API from a library we do not have, in a record that says
rulings are normative and that code review cites them by number.

**What was actually built.** A provider-agnostic verifier, which is the better design and is the
reason the mismatch is worth writing down rather than quietly deleting. `OidcTokenVerifier` validates
any OIDC issuer's RS256/ES256 token against its published JWKS; `JwtTokenVerifier` does HS256 for
dev and service-to-service. Neither knows what Firebase is. Generalising the verifier is what
dropped the one assertion that was Firebase-specific — revocation is not an OIDC concept, because
there is nothing in a signed JWT that a stateless verifier can consult to learn it was withdrawn.

**The correction that matters most, and it is not the one the ticket expected.** It is tempting to
say the gap is harmless because a revoked token "reads as `auth/invalid-token`, which signs the user
out". **It does not.** Revoking a Firebase session invalidates the *refresh* token and sets a
valid-since watermark; the ID token already in the client's hand keeps its valid signature, issuer,
audience and `exp`. Nothing in `auth/claims.py` reads `auth_time` or any watermark, so for the
remainder of that hour the request is **accepted, with a 200**. What eventually signs the user out is
D-7: at expiry the client force-refreshes, the refresh fails at Firebase, and it signs out. The
client's behaviour is correct; the mechanism is expiry, not rejection. A gap that is bounded by a
timer is a smaller thing than a gap with no bound — but it is not nothing, and the record has to say
which one it is.

**Why amend rather than implement.** Three reasons, in order of weight:

1. **Implementing it costs the seam.** `check_revoked` would mean adding the Firebase Admin SDK and
   a Firebase-shaped branch to a verifier whose whole value is that it is provider-agnostic
   (`AUTH_PROVIDER=oidc` is documented as "Firebase, Google, any SSO"). The generic alternative —
   an introspection or watermark lookup per request — is a network call on the hot path of every
   authenticated request, against a p95 budget of 150 ms.
2. **The exposure is bounded and small.** One hour, on provisioned-only accounts, behind a per-token
   rate limit ([ADR-G](ADR-G-secret-handling.md) D-7) with an audit trail. For a demo application
   holding one third-party model key, that is a trade a reader can check rather than a hole.
3. **Nothing downstream is waiting for it.** `AUTH_PROVIDER=jwt` in dev has no revocation concept at
   all, and the client is already correct (D-7).

**What is deliberately *not* claimed.** That the service supports revocation by another means; that
an hour is negligible; or that the compliance corpus's IdP-side revocation procedures constitute a
technical control in this service. They are an operational control with a latency, and D-12 names
the latency.

**Still the TL's to ratify:** D-11 and D-12 themselves; whether the one-hour window is acceptable
for the demo or whether Epic 1 should carry a revocation ticket; and whether `auth/revoked-token`
should be reserved in the code list as a forward-compatible name or left out entirely (this
amendment leaves it out, because a reserved code a client might branch on is the defect D-6 just
fixed).

## Amendment 2026-09-21 — provisioning becomes a registry (spec backend/0027)

- **D-13** **Provisioning is data in this service, joined on the verified e-mail.** D-5 said accounts are
  "provisioned by us, never self-signup" and located that at the identity provider, by hand. The
  design (`Login.dc.html`) needs the service to *answer* the question — *This account isn't
  provisioned for the preview* — and an operator to invite, approve and revoke from the product. So a
  `users` table holds who was invited, `GET /v1/me/access` joins a verified token's `email` against
  it, and `admin`-scoped routes manage it, each audited. The identity provider still proves identity
  and still holds every credential; this service holds only e-mails and statuses.
- D-5a is unchanged: enabling Google sign-in at the IdP — which the design draws — is the deliberate
  amendment D-5a exists to force, to be ratified with the Firebase project.
- On a laptop, where there is no Firebase, `POST /v1/preview-sign-ins` mints the HS256 development
  token for a provisioned e-mail; it is refused under `oidc`, so no deployed stack can issue a
  credential. Spec 0027 OD-3 carries the security argument.
