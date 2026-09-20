# 0010 — The A2A surface: JSON-RPC at the root, agent card at the well-known path

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-3](https://somniosoftware.atlassian.net/browse/GGU-3) · **Related:** 0006 (agent host), 0009 (prompt), [ADR-J](../../docs/adr/ADR-J-rest-api-and-a2a-surface.md), [ADR-D](../../docs/adr/ADR-D-a2ui-streaming-transport.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

The agent host runs a turn, the presentation layer shapes payloads and the
prompt teaches the model both catalogues — and **none of it is reachable**.
There is no HTTP surface a client can call. Every one of those tickets merged
as code nothing can invoke.

There is a second problem the ticket names and this spec must not paper over:
the A2A protocol is **JSON-RPC posted to the service root**, which contradicts
the standing rule that every endpoint here is RESTful.

## 2. Scope

**In**

- `GET /.well-known/agent-card.json` — the bootstrap document, **public**.
- `POST /` — JSON-RPC, `message/stream`, answering `text/event-stream`.
- `services/a2a_service.py` — the thin adapter (ADR-J D-2).
- `services/agent_card_service.py` — the card, skills generated from the tool
  registry.
- Splitting middleware installation out of the composition root, which the
  change pushed over the line budget.

**Out**

- **Conversation history.** `contextId` is echoed, not resolved — sessions are
  GGU-46, on a different branch. See OD-2.
- **Incremental streaming.** See OD-3.
- `tasks/resubscribe`, push notifications, state-transition history: the card
  advertises none of them.

## 3. API contract

| Method & path | Auth | Answers |
|---|---|---|
| `GET /.well-known/agent-card.json` | **none** | `AgentCard` |
| `POST /` | Bearer | `text/event-stream` for `message/stream`; a JSON-RPC error object (HTTP 200) otherwise |

**Errors come in two shapes, and that is deliberate** (ADR-J D-3). A fault
*inside* the protocol — unknown method, bad parameters — is a JSON-RPC error
object at HTTP 200. A fault *before* the envelope is reached — no token, rate
limit — is still an RFC 9457 problem document at its real status. A client
parses both, and the agent card's documentation says so rather than leaving it
to be discovered.

Event order for one turn: `status-update{working}` → `message` →
`status-update{completed | input_required}`. A turn that produced a surface
ends **`input_required`**, which is a normal terminal state, not an error
(ADR-D D-3).

## 4. Data model & migration

None.

## 5. Security notes

- **`POST /` is authenticated** through the same `PrincipalDep` as `/v1/**`
  (ADR-J D-4). The turn runs as the verified subject.
- **The agent card is public** — a new exception to the rule that every route
  is authenticated, so per `.claude/rules/backend/security.md` it is noted here
  and called out for sign-off (OD-1). It carries no subject data: what the
  service is, where to post, and what it can be asked for.
- **`contextId` is never trusted.** It is echoed for correlation only. When
  sessions land it is resolved *against the authenticated subject* or treated
  as unknown (ADR-J D-4, ADR-A) — never as a key on its own.
- **No error body carries internal text.** JSON-RPC messages are fixed strings;
  a failed turn reports `AppError.code` and `detail`, both already safe for an
  anonymous caller. Asserted by a test.
- The public route list lives in one named constant in the contract test, and
  a second test **calls every other route without a token and insists on a
  401** — documenting a 401 is not the same as enforcing one, and a controller
  that copies the documented responses but forgets `PrincipalDep` would
  otherwise pass every check while being wide open.
- **Known limitation:** `BodyLimitMiddleware` inspects `Content-Length`, so a
  body sent with chunked transfer encoding is not bounded by it. `POST /` is
  the first route that reads the raw body itself, which makes this
  load-bearing here for the first time. The envelope's own bounds (`id`,
  `method`, `params`, message parts) limit what survives parsing, but the read
  itself is unbounded. Recorded as OD-6 rather than left to be discovered.

## 6. Acceptance criteria

1. **AC-1** — The agent card is readable **without** a token, advertises the
   public URL (never the bind address) and one skill per registered tool.
2. **AC-2** — `message/stream` with a valid token answers `text/event-stream`
   with the documented event order and terminal state.
3. **AC-3** — An unknown or unsupported method is a **JSON-RPC error object at
   HTTP 200**, not a transport error.
4. **AC-4** — `POST /` without a token is refused with a problem document.
5. **AC-5** — Both routes are documented in OpenAPI under their own tag, and
   the contract tests pass unchanged.
6. **AC-6** — `make gate` green.

## 7. Test plan

| AC | Tests |
|---|---|
| AC-1 | `test_a2a_card.py` — public read, public URL not the bind address, skills equal the registry |
| AC-2 | `test_a2a_rpc.py::test_a_turn_streams_a_working_status_then_the_answer`; `test_a2a_service.py` for both terminal states |
| AC-3 | unknown method, `tasks/cancel`, bad params, non-envelope body, non-JSON body |
| AC-4 | `test_a_turn_without_a_token_is_refused` |
| AC-5 | the existing OpenAPI contract tests, with `PUBLIC` extended and justified |
| — | `test_no_error_body_carries_internal_text`; the adapter's failure path, which must report **inside** the stream |

Mutation checks: **no new** auth or masking logic — the route reuses
`PrincipalDep` and the existing problem handler.

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | A second public route — acceptable? | TL — **yes**, sign-off requested in the PR | A client cannot present a token before it has bootstrapped, so a private card makes the protocol unusable. It exposes no subject data. `security.md` and the contract test's `PUBLIC` constant both name it. |
| OD-2 | What happens to `contextId` without sessions? | TL — **echo, never resolve** | Sessions are GGU-46, on another branch. Echoing keeps the client's correlation working; resolving would need the session store. The rule for when it lands is already decided and unchanged: resolve against the subject or treat as unknown. **Every turn currently starts with empty history** — stated in the module docstring so nobody mistakes it for a bug. Still open after [spec 0012](0012-delivery-followups.md), whose OD-3 records why: the session code is not on this branch. |
| OD-3 | Is the stream incremental? | TL — **not yet, and the PR says so** | ADR-K D-19 wants each surface emitted as it is ready. `run_turn` returns a finished turn rather than yielding, so the stream is well-formed but arrives in one burst. Making the loop a generator changes `a2a_service.py` only. Calling this "streaming" without the caveat would be the dishonest option. **Closed by [spec 0012](0012-delivery-followups.md) AC-1/AC-2**: `run_turn_events` yields, and the adapter forwards a `render-intent` event per surface. |
| OD-4 | `tasks/cancel`, which ADR-D D-9 leaves unowned? | TL — **documented refusal** | The client calls it on every cancellation and nothing implements it, so today it would be a 500. A JSON-RPC "unsupported operation" is a truthful answer the client can handle. D-9 still needs an owner to decide whether to implement it. |
| OD-6 | The body limit does not cover chunked encoding, and this is the first route that reads the raw body. | TL — **carried** | Every field of the envelope is bounded, so a chunked body cannot produce an oversized *response* or reach a method with unbounded parameters. What is not bounded is the read itself. Fixing it properly means counting bytes in the middleware's body stream, which changes every route's behaviour — worth doing deliberately, not inside a feature PR. |
| OD-5 | ADR-D is still **Proposed**, not Accepted. | TL | This spec implements D-1, D-2, D-3, D-7 and D-9 as written. If ratification changes any of them, this surface changes with it. Flagged rather than silently treating a proposal as a decision. |

## 9. Rollout & observability

No flag. The turn already emits one metric and one log line carrying no prompt
text; the adapter adds none. With no `GEMINI_API_KEY` the null client answers
honestly that no model provider is configured, which is what the manual run
below shows.
