# API contract — backend A2A / A2UI service

- **Tickets:** [GGU-3](https://somniosoftware.atlassian.net/browse/GGU-3) (service) · [GGU-46](https://somniosoftware.atlassian.net/browse/GGU-46) (auth) · consumed by [GGU-2](https://somniosoftware.atlassian.net/browse/GGU-2) (client)
- **Status:** Draft for review · **Anchor:** `main` @ `410bb9d`
- **Governing records:** [ADR-A](../../adr/ADR-A-session-identity.md) · [ADR-B](../../adr/ADR-B-auth-credential-contract.md) · [ADR-D](../../adr/ADR-D-a2ui-streaming-transport.md)

> **Why this document exists.** GGU-3's in-ticket endpoint table described `POST /v1/session` — a
> service that does not exist and will not be built. A developer coding to that table would build the
> wrong thing. The real surface is A2A JSON-RPC at the service root. This is the contract the client
> codes to.

## 1. `GET /healthz`

| | |
|---|---|
| Guard | **none** (ADR-B D-3) |
| Success | `200 {"status":"ok"}` |
| Notes | Cloud Run startup probe. MUST NOT probe Gemini or any downstream — a liveness check that depends on the model turns a quota blip into a restart loop. |

## 2. `GET /.well-known/agent-card.json`

| | |
|---|---|
| Guard | **none** (ADR-B D-3 — the client needs the card to bootstrap, before it has a token) |
| Success | `200`, an `AgentCard` with `capabilities.streaming = true` and the A2UI v0.9 extension listed |

**`url` MUST be the public service URL** (ADR-D D-7). Today it is derived from the bind address, so
a Cloud Run deployment advertises `http://0.0.0.0:8080`. Requires a `PUBLIC_BASE_URL` setting
independent of host/port. The same setting feeds the `/static/*` logo URL rewriting (§5).

## 3. `POST /` — JSON-RPC `message/stream` — the main surface

| | |
|---|---|
| Guard | `Authorization: Bearer <Firebase ID token>` |
| Required headers | `Authorization` · `X-A2A-Extensions: https://a2ui.org/a2a-extension/a2ui/v0.9` · `Accept: text/event-stream` |
| Success | `200`, SSE stream of `TaskStatusUpdateEvent` carrying A2UI parts |

**Request** — JSON-RPC envelope, `params.message` with `parts[]` (`TextPart` / `DataPart`),
optional `contextId`, `referenceTaskIds`, `metadata.a2uiClientCapabilities`.

**`contextId` is scoped within a uid** (ADR-A D-2). A `contextId` belonging to another uid is
treated as not-found — a new session is created — and the response MUST NOT reveal that the other
session exists.

**Streaming semantics.** The server emits `TaskState.working` status updates as the agent composes,
then a terminal state: `input_required` for a surface awaiting user action, `completed` for a
finished order. **`input_required` is a normal terminal state, not an error** (ADR-D D-3).

**Omitting `X-A2A-Extensions` silently degrades the response to the plain text agent** — no A2UI
parts, no surface, no error. The client's own header assembly must preserve it (see
[GGU-2 contract](../GGU-2/api-contract.md)).

## 4. `POST /` — JSON-RPC `tasks/cancel`

**Currently always errors** — the handler raises `UnsupportedOperationError`, while the client calls
it on every cancellation signal. ADR-D D-9 requires an owner: implement it, or document it as
unsupported and stop the client calling it. Until then, every user-initiated cancel surfaces a
server error.

## 5. `GET /static/*`

Coin logo images, unauthenticated. URLs are rewritten from the service base URL, so this is the
second consumer of the `PUBLIC_BASE_URL` fix in §2.

⚠️ The static mount is **CWD-relative**. Any test that constructs the app fails unless the working
directory is the backend package; make the path `__file__`-relative.

## 6. Error contract (RFC 9457)

The single largest under-specification found during refinement. Today the client can only observe an
opaque HTTP status, so it cannot distinguish *expired* (→ refresh and retry once) from *revoked*
(→ sign out) from *rate-limited* (→ back off). ADR-B D-7's refresh policy is unimplementable without
this table.

| Status | `type` | `title` | When | Client action |
|---|---|---|---|---|
| 401 | `…/errors/auth-missing-token` | Missing credentials | no `Authorization` header | sign out → login |
| 401 | `…/errors/auth-invalid-token` | Invalid credentials | signature / `iss` / `aud` fail | sign out |
| 401 | `…/errors/auth-expired-token` | Expired credentials | `exp` past | **force-refresh + retry once** (ADR-B D-7) |
| ~~401~~ | ~~`…/errors/auth-revoked-token`~~ | ~~Revoked credentials~~ | ~~`check_revoked` hit~~ | **struck 2026-09-20 (GGU-87)** — never built, and nothing can raise it. A revoked token is accepted until `exp`; see [ADR-B](../../adr/ADR-B-auth-credential-contract.md) D-12 |
| 403 | `…/errors/session-forbidden` | Session not accessible | `contextId` belongs to another uid (ADR-A D-2) | start a new session |
| 400 | `…/errors/malformed-request` | Malformed request | JSON-RPC or part validation failure | non-retryable |
| 429 | `…/errors/rate-limited` | Too many requests | per-uid limit (ADR-G D-7) | back off; honour `Retry-After` |
| 500 | `…/errors/internal` | Internal error | unhandled | generic message; never leak model or key detail |
| 503 | `…/errors/model-unavailable` | Model unavailable | Gemini exhausted retries | retry-after |

**Open — needs a ruling before the client is built.** A2A is JSON-RPC, so an RFC 9457 problem
document returned on a plain HTTP 401 is **not** a JSON-RPC error object, and the client parses the
two paths differently. Specify which envelope carries each class of error: transport-level rejections
(auth, rate limit) as HTTP problem documents before the JSON-RPC layer, or everything wrapped as
JSON-RPC errors. Pick one and state it here.

## 7. Capacity

The stream-parser LRU is bounded per process (`_max_parsers = 1000`, keyed by session). An eviction
mid-stream corrupts parsing for that session. Document this as the concurrency contract, or make
eviction refuse to drop a session with an open stream.
