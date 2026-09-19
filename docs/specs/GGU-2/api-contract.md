# Client contract — auth and request assembly

- **Tickets:** [GGU-2](https://somniosoftware.atlassian.net/browse/GGU-2) · pairs with [GGU-46](https://somniosoftware.atlassian.net/browse/GGU-46)
- **Status:** Draft for review · **Anchor:** `main` @ `410bb9d`, `genui_a2a` 0.10.1
- **Governing record:** [ADR-B](../../adr/ADR-B-auth-credential-contract.md) · wire format: [GGU-3 api-contract](../GGU-3/api-contract.md)

This is not a server API — it is the half of the credential contract the client owns, written down
so the client and backend can be built in parallel.

## 1. Header set on every A2A request

```
Authorization: Bearer <Firebase ID token>
X-A2A-Extensions: https://a2ui.org/a2a-extension/a2ui/v0.9
Accept: text/event-stream
```

⚠️ **The `X-A2A-Extensions` header must be re-supplied by the client.** The convenience
`A2uiAgentConnector(url: …)` constructor sets it internally and offers no way to add `Authorization`
alongside it. GGU-2 must switch to the `A2uiAgentConnector(client: A2AClient(…))` form — **and then
set `X-A2A-Extensions` itself**. Dropping it does not fail loudly: the backend silently serves the
plain text agent and no surface ever renders.

## 2. Token acquisition and refresh

- Acquire with `getIdToken()`; force-refresh with `getIdToken(true)`.
- **Refresh seam (ADR-B D-9):** `HttpTransport.authHeaders` is `final` but is spread **per request**, so there is no interceptor. Hold a **mutable** `Map<String, String>`, pass it to the transport, and rewrite its `Authorization` entry before each send. This is a workaround pinned to `genui_a2a 0.10.1` — revisit on upgrade.
- **Retry policy (ADR-B D-7):** on `auth/expired-token`, force-refresh and retry **exactly once**. Any other 401/403 signs the user out. No retry loop — a second 401 surfaces the error.
- **Mid-stream expiry (ADR-B D-8):** the token is validated once at stream open; expiry mid-stream does not terminate the stream.

## 3. Negative contract — what must never happen

- The Firebase **refresh token** never leaves the client. Only the short-lived ID token reaches our backend. A test asserts the outbound request carries no refresh token.
- No Gemini key, service account, or admin credential ships in the client bundle. Only Firebase **public** config.
- `google-services.json` / `GoogleService-Info.plist` are git-ignored, never committed (ADR-B D-10).

## 4. Sign-out semantics

Sign-out clears auth state and returns to login. **Open:** what happens to an in-flight SSE stream —
abort it, or let it drain? Specify before the shell work in Epic 5.

## 5. Provisioning interface

`provision_user.py` is the operator tool that creates accounts, since there is no public signup. Its
only consumer is [GGU-12](https://somniosoftware.atlassian.net/browse/GGU-12). Specify here:

- argument list and the required service-account env var;
- what it writes and where (**never** the credential itself into any repo file);
- idempotency on a duplicate email;
- its path — GGU-2 and GGU-12 currently disagree. **One location, stated here.** With `docs/` now
  existing, `docs/provisioning-runbook.md` is the better home for the runbook.

⚠️ **Sequencing:** this script needs `firebase-admin`, which is added by GGU-46. It cannot land first.
