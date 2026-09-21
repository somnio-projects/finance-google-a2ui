# ADR-J — Two surfaces: a RESTful `/v1` API and the A2A protocol adapter

- **Status:** **Accepted** — ratified by the TL (Lautaro Bertuzzi) on 2026-09-19
- **Gates:** GGU-3, GGU-46, GGU-14, GGU-36/37/38/39, and every future backend ticket
- **Evidence anchor:** `develop` @ PR #2 (the FastAPI foundation)
- **Supersedes in part:** [ADR-C](ADR-C-backend-module-layout.md) §layout for the deleted sample; complements [ADR-D](ADR-D-a2ui-streaming-transport.md)

## Context

> **In the context of** a standing project rule that every endpoint be strictly RESTful and
> exhaustively documented in OpenAPI, **facing** the fact that A2A — the protocol Google's client
> SDK speaks — is JSON-RPC `message/stream` POSTed to the service **root** with an agent card at
> `/.well-known/agent-card.json` ([ADR-D](ADR-D-a2ui-streaming-transport.md) D-1), **we decided** to
> run **two clearly separated surfaces** on one service, **and neglected** both "make everything
> REST and break the A2A client" and "make everything JSON-RPC and abandon the REST rule",
> **to achieve** a reference implementation that is idiomatic on our own API and wire-compatible
> with Google's SDK, **accepting that** the service exposes two documentation styles and that a
> reader must be told which is which.

The rule and the protocol cannot both govern the same path. They can govern different paths.

## Decision

- **D-1 — `/v1/**` is ours and is strictly RESTful.** Resource nouns in the plural, HTTP verbs carrying the semantics, correct status codes, query parameters for filtering/sorting/pagination, sub-resources for relations, RFC 9457 problem documents for every error. `.claude/rules/backend/api-design.md` applies in full and is enforced by `tests/unit/api/test_openapi_contract.py`.
- **D-2 — The A2A surface is an adapter, not a second architecture.** The JSON-RPC root and the agent card are implemented to Google's specification and are **thin**: they translate the protocol envelope and delegate to the same services the REST API uses. No business logic lives in the adapter; no service knows the protocol exists.
- **D-3 — The A2A surface is documented too.** It appears in OpenAPI as its own tag with the JSON-RPC envelope described, its streaming content type declared, and a link to the A2A specification. "Not REST" is not a licence for "not documented".
- **D-4 — Session identity is shared.** Both surfaces resolve the caller through the same `PrincipalDep` and operate on the same subject-scoped sessions (GGU-46). The A2A `contextId` is **never** trusted as a session key on its own — it is resolved against the authenticated subject, or rejected ([ADR-A](ADR-A-session-identity.md)).
- **D-5 — The client is told which surface to use for what.** Conversation and streaming go through A2A; everything else the Flutter client needs (sessions list, holdings, flags, identity) goes through `/v1`. The split is recorded in the client-facing API spec.
- **D-6 — New functionality defaults to REST.** A new capability is exposed on `/v1` unless the A2A protocol requires otherwise; extending the JSON-RPC surface needs a decision recorded here.
- **D-7 — The A2A surface accepts exactly one non-text part kind, `data`, and no other extension.** A `data` part carries a **registered action id and bounded scalar arguments** — at most eight, each a bounded string, an integer, a boolean or `null`, with no nested objects and no arrays — and a message carries either one such part or prose, never both. The turn's prompt is composed **server-side** by the registered action; the client supplies values and never the sentence, the field path, the tool name or the view id ([ADR-K](ADR-K-response-shaping.md) D-3). An unknown action is `-32602`, an undeclared or out-of-range argument is `-32602` naming the argument and never its value, and the capability being switched off is `-32601`. This is the decision D-6 requires, and it is deliberately narrow: **it licenses this one part kind, not a general extension mechanism.** A second kind needs its own ruling here. Spec `backend/0022-surface-actions.md` carries the reasoning, including why this is a message rather than `POST /v1/surface-actions` — a "create an action" resource nobody can `GET` is the RPC escape hatch `api-design.md` forbids, wearing a noun, and it would hand the Flutter client a **third** error shape to parse.

## Consequences

**Positive.** The showcase demonstrates both an idiomatic REST API (documented well enough to generate a client) and correct A2A interoperability. Our rules stay enforceable without exceptions or special cases inside `/v1`. The protocol can move — A2A is alpha — without touching the services.

**Negative / accepted.** Two surfaces mean two sets of tests and two documentation idioms. The adapter is an extra layer between the client and the services. A reader who lands on `/docs` must be told that the root path is a protocol endpoint, which D-3 handles. Under D-7 the protocol surface now accepts structured input, so the bounds on that input are a security boundary rather than a convenience, and they are enforced by the envelope before anything reaches the registry.

**Neglected alternatives.** *Everything REST*: would break `genui_a2a`, the Google client SDK the showcase exists to demonstrate. *Everything JSON-RPC*: would throw away the API-quality story that is half the point of the reference app, and would leave the Flutter client doing RPC for plain reads.

## Compliance

Every PR that adds an endpoint states which surface it belongs to. The REST rule is enforced by the
OpenAPI contract tests; the A2A adapter is enforced by its own integration tests against the client
SDK's expectations (GGU-3).
