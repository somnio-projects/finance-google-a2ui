# ADR-B — Auth credential contract

- **Status:** Accepted (TL, 2026-09-18)
- **Gates:** GGU-2 (client), GGU-46 (backend)
- **Evidence anchor:** `main` @ `410bb9d`, `genui_a2a` 0.10.1

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

### Two hard blockers discovered during refinement

1. **There is no seam to attach the header.** `LandingRepository` calls `A2uiAgentConnector(url: …)`, and that constructor path hardcodes `authHeaders: {'X-A2A-Extensions': …}` with no parameter to add more. GGU-2 must switch to the `A2uiAgentConnector(client: A2AClient(…))` form **and re-supply `X-A2A-Extensions` itself** — omit it and A2UI silently degrades to the text agent.
2. **There is no interceptor.** `HttpTransport.authHeaders` is `final Map<String, String>` but is spread **per request**. The only viable seam is a *mutable* map whose `Authorization` entry is rewritten before each send.

## Decision

- **D-1** Credential = Firebase **ID token** only. The refresh token MUST NEVER be sent to our backend; a test asserts the outbound request carries none.
- **D-2** Transport = `Authorization: Bearer <idToken>` on every A2A request, with `X-A2A-Extensions` preserved alongside it.
- **D-3** `GET /.well-known/agent-card.json` and `GET /healthz` are **unauthenticated**. Every other path requires a valid token.
- **D-4** Verification asserts `iss == https://securetoken.google.com/finance-a2ui`, `aud == finance-a2ui`, unexpired, `check_revoked=True`.
- **D-5** ~~Allow-list required~~ — **amended 2026-09-18 (TL): no uid allow-list.** Access control is (a) email/password is the sole enabled provider and (b) accounts are provisioned by us, never self-signup.
- **D-5a** **Email/password is the only enabled Firebase Auth provider.** Recorded as a ruling so that enabling a second provider is a deliberate amendment to this ADR rather than a silent console toggle — that toggle is the only way the D-5 control could quietly disappear.
- **D-6** Rejections use typed, distinguishable codes: `auth/missing-token`, `auth/invalid-token`, `auth/expired-token`, `auth/revoked-token` → `401`; `session-forbidden` → `403`. See `docs/specs/GGU-3/api-contract.md`.
- **D-7** Client refresh policy: force-refresh + **exactly one** retry on `auth/expired-token`; any other 401/403 signs the user out. No retry loop.
- **D-8** The token is validated **once at stream open**. A token expiring mid-stream does not terminate the stream. *(Open: revisit against the Cloud Run request timeout.)*
- **D-9** Refresh seam: the connector holds a **mutable** `Map<String, String>` whose `Authorization` entry is rewritten before each send. Documented workaround pinned to `genui_a2a 0.10.1`; revisit on upgrade.
- **D-10** No credential, service account, `google-services.json` or `GoogleService-Info.plist` is committed. Only Firebase **public** config ships client-side.

## Consequences

D-5 accepts a real residual risk, bounded by D-5a: token verification alone admits any user in the
`finance-a2ui` project. With one provider and provisioned-only accounts that set equals the intended
set. Adding a provider without amending this ADR silently widens backend access to the Gemini key.
